#[test_only]
module raffle::raffle_tests {
    use raffle::raffle::Raffle;
    use sui::clock::{Self, Clock};
    use raffle::raffle;
    use std::string::String;
    use sui::test_scenario::{Self, Scenario};


    fun set_up():Scenario{
        let scenario_val = test_scenario::begin(@0x123);
        scenario_val
    }

    fun end(scenario_val : Scenario){
        test_scenario::end(scenario_val);
    }


    fun test_create_raffle(){
        // Create a raffle
        raffle::init();
    }

    fun test_create_activity(name: String, endTime : u64, winnerCount: u64, isOpen : bool, password: String, scenario_val : Scenario) : UID{
        let raffle = scenario_val::take_shared<Raffle>(&scenario_val);
        let clock = scenario_val::take_shared<Clock>(&scenario_val);
        let ctx = scenario_val.ctx();
        raffle::create_activity(raffle, name, endTime, winnerCount, isOpen, password, clock, ctx);
    }
}
