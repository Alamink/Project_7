
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational',
             [ { label: 'Operational Status', error: error, value: result} ]);
        });  

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number-Oracle').selectedIndex;
            console.log("submitted transactoin : "+flight);
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', 
                [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        });

        DOM.elid("buy-insurance").addEventListener('click',()=>{
            let flight = DOM.elid('flight-number-buy').selectedIndex;
            let amount = DOM.elid("num-amount-wei").value;
            console.log("buy insurance : "+flight + " amount: "+ amount);
            contract.buyInsurance(flight,amount,(error, result) => {
                display('Buy insurance', 'Trigger Insruance payment', 
                [ { label: 'Pay insurace for flight', error: error, value:result.flight + ' ' + result.timestamp} ]);
            });
        });
        DOM.elid("withdraw-blance").addEventListener('click',()=>{
            console.log("Withdraw credit");
            // DOM.elid("balance").innerHTML = update value;
            contract.withdraw((error, result) => {
                display('withdraw Balance', 'Trigger payout for ', 
                [ { label: 'Pay passenger for flight dalyed', error: error,value:"Money sent back"} ]);
            });
        })
        contract.getFlightStatus((error, result) =>{
               if(result.status == 20){
                   // update credit 
                   console.log("Filght is delayd, update balance");
                   contract.updateBlance();     
            }
            display("Flights","Trigger flight status",              
            [ { label: 'Flight Status', error: error, value: result.flight +" "+ result.timestamp + "  "+result.status} ]);
        });
    
    });    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    });
    displayDiv.append(section);

}







