
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  
  const TEST_ORACLES_COUNT = 40;
      // Watch contract events
      const STATUS_CODE_UNKNOWN = 0;
      const STATUS_CODE_ON_TIME = 10;
      const STATUS_CODE_LATE_AIRLINE = 20;
      const STATUS_CODE_LATE_WEATHER = 30;
      const STATUS_CODE_LATE_TECHNICAL = 40;
      const STATUS_CODE_LATE_OTHER = 50;

  let flight = "SA100";
  let timestamp = Math.floor(Date.now() / 1000);
  let passanger = accounts[10]; 
  let oneEther = web3.utils.toWei('1', 'ether');
  let OneAndHalfEther = web3.utils.toWei("1.5","ether");
  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    // await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it('can register oracles', async () => {
    
    // ARRANGE
    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();
    // ACT
    for(let a=99; a>TEST_ORACLES_COUNT; a--) {      
      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
      // console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    }
  });

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });
  it('Ability to register an airline 4 airline without voting, airline must payfund', async function(){
    assert.equal(1,await config.flightSuretyData.getNumberOfRegisteredAirLines.call(), "Contract should have one airline already");
    assert.equal(0,await config.flightSuretyData.getNumberOfFundedAirLines.call(), "Contract should not have any funded airlines");
    await config.flightSuretyApp.payFund({value: web3.utils.toWei('11', 'ether')});
    assert.equal(1,await config.flightSuretyData.getNumberOfFundedAirLines.call(), "Contract should have one funded airline");
    await config.flightSuretyApp.registerAirline(accounts[1],"AlaminAirLine");
    await config.flightSuretyApp.registerAirline(accounts[2],"3");
    await config.flightSuretyApp.registerAirline(accounts[3],"4"); // to check that other airlines can register
    assert.equal(4,await config.flightSuretyData.getNumberOfRegisteredAirLines.call(), "Contract should have 4 airlines");
    await config.flightSuretyApp.payFund({from : accounts[1] ,value: web3.utils.toWei('11', 'ether')});
    await config.flightSuretyApp.payFund({from : accounts[2] ,value: web3.utils.toWei('11', 'ether')});
    await config.flightSuretyApp.payFund({from : accounts[3] ,value: web3.utils.toWei('11', 'ether')});
    assert.equal(4,await config.flightSuretyData.getNumberOfFundedAirLines.call(), "Contract should not have any funded airlines");
  });
  // it('Test get airline function', async function(){

  // });
  it("Ability to register an airline with voting, airline must be found to vote", async function(){
    await config.flightSuretyApp.registerAirline(accounts[4],"4", {from:accounts[0]});
    // should not be added, need to go over voting.
    assert.equal(4,await config.flightSuretyData.getNumberOfRegisteredAirLines.call(), "Contract should have 4 airlines");  
    // should fail becuase double voting
    
    let reverted = false;
    try {
      await config.flightSuretyApp.registerAirline(accounts[4],"4", {from:accounts[0]});    
    } catch (e) {
        reverted = true;
    }
    assert.equal(reverted, true, "Can not have one airline do double voting");
    await config.flightSuretyApp.registerAirline(accounts[4],"4", {from:accounts[1]});    
    assert.equal(5,await config.flightSuretyData.getNumberOfRegisteredAirLines.call(), "Contract should have 5 airlines after runing voting");  
  });
  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: accounts[1] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[5];

    let result = true;
    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: accounts[4]});
    }
    catch(e) {
      result = false;
    }

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });
  it("Ability to register Flight form funded airline", async()=>{
    let result = true;
    try{
    await config.flightSuretyApp.registerFlight(flight,timestamp,{from: accounts[1]});
    }catch(e){
      result = false;
    }
    assert.equal(result, true, "Funded AirLine should be able to register a flight");
  });
  it("Can not register Flight form non-funded airline", async()=>{
    let result = true;
    try{
    await config.flightSuretyApp.registerFlight(flight,timestamp,{from: accounts[4]});
    }catch(e){
      result = false;
    }
    assert.equal(result, false, "Non-Funded AirLine should not be able to register a flight");
  });
  it("Passanger can buy insurnace", async()=>{
      let result = true
      try{
       await config.flightSuretyApp.buyInsurance(accounts[1],flight,timestamp,{from: passanger, value: oneEther});
      }catch(e){                                                                                
        result = false
        console.log(e);
      }
      assert.equal(result, true, "passanger should be able to buy insurnace for any regsted flight");
      let flightKey = await config.flightSuretyData.getFlightKey(accounts[1],flight,timestamp);
      let balance = await config.flightSuretyData.getPassengerInsruranceAmount(passanger,flightKey);
      assert.equal(balance,oneEther , "Passanger should 1 ether for flight insurance");

  });
  it("Passanger will get credit when flight is delayed", async()=>{
    let balance = await config.flightSuretyData.getPassengerCreditBalance(passanger);
      assert.equal(balance,0, "Passanger should not have any credit yet");

      await config.flightSuretyApp.fetchFlightStatus(accounts[1], flight, timestamp);
      
        for(let a=99; a>TEST_ORACLES_COUNT; a--) {
          // console.log("orcal # "+a);
          // Get oracle information
          let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
          for(let idx=0;idx<3;idx++) {
            try {
              // Submit a response...it will only be accepted if there is an Index match
              await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], accounts[1], flight, timestamp, STATUS_CODE_LATE_AIRLINE, { from: accounts[a] });
            }
            catch(e) {
              // Enable this when debugging
              //  console.log('\nError', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
            }
          }
        }
       balance = await config.flightSuretyData.getPassengerCreditBalance(passanger);
      assert.equal(balance, OneAndHalfEther, "Passanger should have 1.5 ether in his balance");
  });
   it("Passanger can withdraw his credit",async()=>{
      let result = false;
      let previousBalance = await web3.eth.getBalance(passanger);
      try{
        await config.flightSuretyApp.withdraw({from: passanger});
        let newBalance = await web3.eth.getBalance(passanger);
        //  result = new BigNumber(newBalance).isGreaterThan(previousBalance);
        result = newBalance > previousBalance;
        console.log("previousBalance : "+previousBalance);
        console.log("newBalance : "+newBalance);

      }catch(e){
        console.log(e);
         result = false;
      }
      
      assert.equal(result, true, "New blanace should be 1.5 ethere more after getting credit");
  });

});
