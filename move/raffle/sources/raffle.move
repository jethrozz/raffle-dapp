
module raffle::raffle;

use std::string::String;
use std::vector;
use sui::vec_map;
use sui::vec_map::VecMap;

public struct Raffle has key , store{
    id: UID,
    activityCount: u64, //活动数量
    activities: vector<Activity>, //已经产生的活动
    activitiesMap : VecMap<address, vector<Activity>>, //记录用户自己创建的活动
}

public struct Activity has key , store{
    id: UID,
    creater: address,
    createTime: u64,
    winnerCount: u64, //中奖人数
    ticketCount: u64, //奖券总数
    tickets: vector<Ticket>, //已经产生的抽奖券
}

/**
奖券 是一个NFT，要满足NFT的标准
*/
public struct Ticket has key, store {
    id: UID, // id
    no: String, // 彩票号
    name: String, //名称
    createTime: u64, //创建时间
    activityId: UID, //活动
    win: bool, //是否中奖
}

public fun init(ctx : &mut TxContext){
    let raffle = Raffle {
        id: new_id(ctx),
        activityCount: 0,
        activities: vector[],
        activitiesMap: vec_map::empty(),
    };
}

