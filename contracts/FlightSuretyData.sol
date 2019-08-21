pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false


    enum AirLineState { // can add other states as well if needed for future.
        DEFAULT, // not registered airline
        Registered, // has been registered 
        Funded // paid the reqire fee or fund
    }
    struct AirLine{ // curent represntion of an AirLine or member of the club 
        AirLineState state; // represnt the airline state 
        string name; // name of the airline
    }
    mapping(address=> AirLine) private airlines;
    uint256 private numberOfRegisteredAirLines;// keep all airlines funded + pending to pay fund
    uint256 private numberOfFundedAirLines ; 
    uint256 public constant FUND_FEE = 10 ether;

 
    mapping(address => mapping(bytes32 => uint256)) passnagerAccount;
    mapping(address => uint256) passnagerCredit;
    // passager address => colleation of all of his flights where he bought insrnace
    // address => flight key => his amount he paid

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
    () 
                                public 
    {
        contractOwner = msg.sender;
        airlines[contractOwner].state = AirLineState.Registered;
        airlines[contractOwner].name = "frist airline";
        numberOfRegisteredAirLines = 1;
        numberOfFundedAirLines = 0;

    }

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
        require(operational, "Contract is currently not operational");
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

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner
    {
            operational = mode;      
        
    }
    function getAccountOwner() external view returns(address)
    {
        return contractOwner;
    }
    function getNumberOfRegisteredAirLines() external view returns(uint)
    {
        return numberOfRegisteredAirLines;
    }
    function getNumberOfFundedAirLines() external view returns(uint)
    {
        return numberOfFundedAirLines;
    }
    function getAirline(address _airline) external view returns(string name, uint256 state)
    {
        name = airlines[_airline].name;
        state = uint(airlines[_airline].state);
        
    }
    function isRegistredAirLine(address _airline)external view returns(bool)
    {
        uint state = uint(airlines[_airline].state);
        if(state == 1 ){ 
            return true;
        }else{
            return false;
        }
    }
    function isFundedAirLine(address _airline)external view returns(bool)
    {
        uint state = uint(airlines[_airline].state);
        if(state == 2){
            return true;
        }else{
            return false;
        }

    }
    function getPassengerInsruranceAmount(address passager, bytes32 key)
        external view returns(uint256)
    {
        return passnagerAccount[passager][key];
    }
    function getPassengerCreditBalance(address passanger)
    external view returns(uint256)
    {
      return  passnagerCredit[passanger];
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            ( 
                                address _airline,   
                                string _name
                            )
                            external
    requireIsOperational
    {
            airlines[_airline].state = AirLineState.Registered;
            airlines[_airline].name = _name;
            numberOfRegisteredAirLines = numberOfRegisteredAirLines.add(1);
    }

    function makeFund(address _payinyAirline) external payable
    requireIsOperational
    {
        // not sure if should I transfer , if so to whom it should go
       address(this).transfer(msg.value); 
        airlines[_payinyAirline].state = AirLineState.Funded;
        numberOfFundedAirLines = numberOfFundedAirLines.add(1);
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (   
                            address passnager,  
                            bytes32 flightKey                        
                            )
                            external
                            payable
                            requireIsOperational
    {
        passnagerAccount[passnager][flightKey] = msg.value;
        address(this).transfer(msg.value); 
        // transfer the value to the woner 
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                address passnager,
                                bytes32 flightKey ,                       
                                uint256 creditAmount
                                )
                                external
                                requireIsOperational
    {
        passnagerCredit[passnager] = passnagerCredit[passnager].add(creditAmount);
        passnagerAccount[passnager][flightKey] = 0;
    }
    
    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address passager
                            )
                            payable
                            external
                            requireIsOperational
    {
       uint256 credit = passnagerCredit[passager];
       require(credit > 0, "No credit");
       passnagerCredit[passager] = 0;
       passager.transfer(credit);
    }
   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund()
                            public
                            payable
    {

    }

    function getFlightKey
                        (
                            address airline,
                            string  flight,
                            uint256 timestamp
                        )
                        pure
                        external
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }
    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }

}

