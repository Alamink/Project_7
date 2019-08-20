import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import 'babel-polyfill';


let gasLimit = 9999999;
let gasPrice = 20000000000;

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress,
  {
    gas:      9999999,
  GasPrice: 20000000000
  });

// registere 50 oracle 
let oraclesNum = 50;
let accounts ;

web3.eth.getAccounts(async(error, accts) => {
  accounts = accts;
  await registerOracles();
  // listen to events....
  
  await flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, 
  async function (error, event) {
    if (error) console.log("OracleRequest error : "+error);
    console.log("alamin event is :"+ Object.keys(event.returnValues));
    for(let i=0; i<=oraclesNum; i++){
      let myIndexes = await flightSuretyApp.methods.getMyIndexes().call({from: accounts[i+49]});
        // console.log("my indexes : "+myIndexes);
        if(myIndexes.indexOf(event.returnValues.index) >= 0){
        let statusCode = 10*(Math.floor(Math.random()*6));
        // oracle submit random status code
        try{
        await flightSuretyApp.methods.submitOracleResponse(
          event.returnValues.index,
          event.returnValues.airline,
          event.returnValues.flight,
          event.returnValues.timestamp,
          statusCode)
          .send(
          {from: accounts[i+49],
            gas: gasLimit, 
            gasPrice: gasPrice
          });
          // console.log("oracle # "+ (i+49) + " submited status = "+ statusCode);
        }catch(e){
          // console.log(e);
        }
       }
    }
});
});





const app = express();

app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    });
});

async function registerOracles(){
    for(let i= 0; i<=oraclesNum; i++){
    try{
    await flightSuretyApp.methods.registerOracle().send({from:accounts[i+49], value : web3.utils.toWei('1', 'ether') });  
    }catch(e){
      // console.log(e);
    }
  }
}

export default app;


