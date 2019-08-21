pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    
    address private contractOwner;          // Account used to deploy contract
    FlightSuretyData flightsuretydata;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
        address[] passengers;
    }
    mapping(bytes32 => Flight) private flights;
         // data for mulit sig 
    mapping(address => address[]) private regstrationQueue;
    uint8 private constant REGISTRATION_VOTING_THREASHHOLD = 4;
    uint256 private constant FUND_FEE = 10 ether;
    uint256 private constant MAX_INSURANCE = 1 ether;

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(flightsuretydata.isOperational(), "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }
    modifier minFund() {
            require(msg.value >= FUND_FEE, "FUND fee must be 10 ether");
            _;
    }
    modifier requireRegistredAirLine()
    { // any registered air lines may register a new one
       require(flightsuretydata.isRegistredAirLine(msg.sender), "Caller is not registered member");
        _;
    }
     modifier requireFundedAirLine()
    {
       require(flightsuretydata.isFundedAirLine(msg.sender) , "Caller did not pay the funding fee");
        _;
    }
    modifier maxInsurance()
    {
        require(msg.value <= MAX_INSURANCE , "Max insrnace is 1 ether");
        _;
    } 
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContract
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        flightsuretydata = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return flightsuretydata.isOperational();  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
    function payFund()
    external
    payable
    requireIsOperational()
    minFund() 
    requireRegistredAirLine()
    {
        if(msg.value > FUND_FEE ){
            msg.sender.transfer(msg.value - FUND_FEE);
        }
        flightsuretydata.makeFund.value(FUND_FEE)(msg.sender);
    }
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (  
                                address _newMember,
                                string _name
                            )
                            external
    requireIsOperational
    requireFundedAirLine
    {
        if(flightsuretydata.getNumberOfRegisteredAirLines() < REGISTRATION_VOTING_THREASHHOLD){ 
            // # of air line is less than 4. 
        flightsuretydata.registerAirline(_newMember,_name);
        }else{
            // # of air line is more than 4. Ex: 5 and above. We must vote
            Multisig(_newMember,_name);
        }
    }

    function Multisig(address _newMember,string _name)
    private
    {
         bool isDuplicate = false;
        for(uint i=0; i<regstrationQueue[_newMember].length; i++) {
            if (regstrationQueue[_newMember][i] == msg.sender) {
                isDuplicate = true;
                break;
            }
        }
        require(!isDuplicate, "Caller has already called this function.");
        regstrationQueue[_newMember].push(msg.sender);

        if ( regstrationQueue[_newMember].length >= (flightsuretydata.getNumberOfRegisteredAirLines().div(2)) ) {
            flightsuretydata.registerAirline(_newMember,_name);
            delete regstrationQueue[_newMember];
        }


    }

   /**
    * @dev Register a future flight for insuring.
    *
    */  
    //  struct Flight {
    //     bool isRegistered;
    //     uint8 statusCode;
    //     uint256 updatedTimestamp;        
    //     address airline;
    // I added a list for passenger buying insurance for this flight  
  // }

    function registerFlight
                                (
                                    string flight,
                                    uint256 timestamp
                                )
                                external
        requireIsOperational
        requireFundedAirLine                        
    {
                      
        bytes32 key = getFlightKey(msg.sender,flight,timestamp);
        require(!flights[key].isRegistered,"Flight is registered");
        flights[key] = Flight(true, STATUS_CODE_UNKNOWN, timestamp, msg.sender, new address[](0));
    }
    
    function buyInsurance(address airline, string flight, uint256 timestamp)
                 external
                 payable
    requireIsOperational
    maxInsurance
    {
         bytes32 key = getFlightKey(airline, flight, timestamp);
         flights[key].passengers.push(msg.sender);
         flightsuretydata.buy.value(msg.value)(msg.sender, key);
    }
    function creditInsureesApp(address passanger, bytes32 flightKey)
    internal
    {
      uint256 amountOfInsurnace = flightsuretydata.getPassengerInsruranceAmount(passanger, flightKey);
      require(amountOfInsurnace > 0 ,"You have no insurnace amount!");
      flightsuretydata.creditInsurees(passanger, flightKey, amountOfInsurnace.mul(15).div(10) );
    }
    function withdraw()
    external
    
    requireIsOperational
    {
        flightsuretydata.pay(msg.sender);
    }
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
                                
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);

        if(statusCode == STATUS_CODE_LATE_AIRLINE){ // refund customer with 1.5 X where is X is max as 1 ether
            // call creditInsureesApp to created all passanger
            for(uint i = 0; i<flights[key].passengers.length; i++){
                creditInsureesApp(flights[key].passengers[i], key);
            }
            delete flights[key].passengers;// to make sure not to pay double
        }
    }
    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
    {
        // bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        // require(flights[flightKey].isRegistered,"Flight is not registered");

        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });
        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
                            requireIsOperational
    {
        // not already registered 
        require(!oracles[msg.sender].isRegistered,"Oracle is already registered");
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");
        
        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
                        requireIsOperational
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            oracleResponses[key].isOpen = false;
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion


}   

contract FlightSuretyData {
    // list all signtrure of the function to be used in the app
    function registerAirline(address,string)  external;
    function isOperational() public view returns(bool);
    function getAirline(address _airline) external view returns(string,uint256);
    function isRegistredAirLine(address _airline)external view returns(bool);
    function isFundedAirLine(address _airline)external view returns(bool);
    function getNumberOfRegisteredAirLines() external view returns(uint);
    function getNumberOfFundedAirLines() external view returns(uint);
    function makeFund(address ) external payable;
    function getPassengerInsruranceAmount(address, bytes32) external view returns(uint256);
    function creditInsurees(address,bytes32 ,uint256) external;
    function pay(address) external payable;
    function buy(address,bytes32)external payable;
}