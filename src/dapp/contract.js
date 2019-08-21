import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import DOM from './dom';


export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress,
            {
                gas:      9999999,
                GasPrice: 20000000000
            });

        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
        this.gasLimit = 9999999;
        this.gasPrice = 20000000000;


        this.flights = 
          [{
            name: 'SA 150',
            timestamp: Math.floor(Date.now() / 1000)
        },
        {
            name: 'SA 250',
            timestamp: Math.floor(Date.now() / 1000)
        },
        {
            name: 'SA 300',
            timestamp: Math.floor(Date.now() / 1000)
        }
    ];
    }
    initialize(callback) {
        this.web3.eth.getAccounts(async(error, accts) => {
            let self = this;

            this.owner = accts[0];
            console.log("# of Register airline: "+ await this.flightSuretyData.methods.getNumberOfRegisteredAirLines().call());
            console.log("# of funded airlines: "+ await this.flightSuretyData.methods.getNumberOfFundedAirLines().call());
            try{
            await this.flightSuretyApp.methods.payFund().send(
                {   from: this.owner ,
                    value: this.web3.utils.toWei('10', 'ether')
                });
            }catch(e){
                console.log("Already paid the fund");
            }
            console.log("accout owner: "+this.owner);
            console.log("# of Register airline: "+ await this.flightSuretyData.methods.getNumberOfRegisteredAirLines().call());
            console.log("# of funded airlines: "+ await this.flightSuretyData.methods.getNumberOfFundedAirLines().call());
            console.log(await self.flightSuretyData.methods.getAirline(this.owner).call());

            let counter = 0;
            
            while(this.airlines.length < 3) {
                counter++;
                this.airlines.push(accts[counter]);
                let name = "SAU"+counter;
                try{
                await self.flightSuretyApp.methods.registerAirline(accts[counter],name)
                .send({ 
                    from:self.owner,
                    gas: this.gasLimit, 
                    gasPrice: this.gasPrice
                });
                await this.flightSuretyApp.methods.payFund().send(
                    {   from:accts[counter] ,
                        value: this.web3.utils.toWei('10', 'ether'),
                        gas: this.gasLimit, 
                        gasPrice: this.gasPrice
                    });
                }catch(e){
                    // console.log(e+" @ " + accts[counter]);
                }
                console.log(await self.flightSuretyData.methods.getAirline(accts[counter]).call());

            }
            while(this.passengers.length < 3) {
                this.passengers.push(accts[counter++]);
            }

            for(let i =0; i<this.flights.length; i++){
                try{
                await self.flightSuretyApp.methods.registerFlight(self.flights[i].name,self.flights[i].timestamp)
                .send({
                    from : self.airlines[0],
                    gas: this.gasLimit, 
                    gasPrice: this.gasPrice
                });
                }catch(e){
                    console.log(e);
                }
            }             
            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ 
                from: self.owner,
                gas: this.gasLimit, 
                gasPrice: this.gasPrice
            }, callback);
    }
    fetchFlightStatus(flight, callback) {
        // fligh is the index of poospble options.
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: self.flights[flight].name,
            timestamp: self.flights[flight].timestamp
        }; 
        console.log("Submitted request to fetchFlight status : "+payload.flight );
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }
    getFlightStatus(callback){
         this.flightSuretyApp.events.FlightStatusInfo({
            fromBlock:0
        }).on('data', event => {
            console.log(event.returnValues);
            callback(null, event.returnValues);
        }); 

    }
    buyInsurance(flight, amount, callback){
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: self.flights[flight].name,
            timestamp: self.flights[flight].timestamp
        }; 
        self.flightSuretyApp.methods.buyInsurance(payload.airline, payload.flight, payload.timestamp)
        .send({
            from: self.passengers[0],
            value: amount
        },(error, result) => {
            callback(error, payload);
            self.updateBlance();
        });
    }
    withdraw(callback){
        let self = this;
        this.flightSuretyApp.methods.withdraw().send({
            from: self.passengers[0]
            },(error,result) =>{
             callback(error,result);
            self.updateBlance();
    });
    }
    async updateBlance(){
        console.log("updating balance");
       let balance = await this.flightSuretyData.methods.getPassengerCreditBalance(this.passengers[0]).call();
        console.log("Balance = "+balance);
        DOM.elid("balance").innerHTML = balance;
    }
    
}