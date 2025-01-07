
module raffle::raffle;

use std::string;
use std::string::String;
use sui::clock::{Self, Clock};
use sui::vec_map;
use sui::vec_map::VecMap;
use std::option::{Self};


public struct Raffle has key , store{
    id: UID,
    activityCount: u64, //活动数量
    activities: vector<Activity>, //已经产生的活动
    activitiesMap : VecMap<UID, Activity>, //活动id
    endedActivities : vector<Activity>, //已经开奖活动
    activitiesInProgress : vector<Activity>, //进行中的活动
    userActivitesMap :  VecMap<address, vector<Activity>>, //记录用户自己创建的活动
}

public struct Activity has key , store, copy{
    id: UID,
    name: String,
    creater: address,
    createTime: u64,
    endTime: u64, // 截止时间
    winnerCount: u64, //中奖人数
    ticketCount: u64, //奖券总数
    currentTicketCount: u64, //当前奖券数量
    password: String, //活动密码，非开放活动需要输入密码
    isOpen: bool, //是否开放
    status: u8, //活动状态 1:进行中 2:已开奖
    tickets: vector<Ticket>, //已经产生的抽奖券
    joinTimes: vector<u64>, //参与者时间 用于中奖者的计算
}

/**
奖券 是一个NFT，要满足NFT的标准
*/
public struct Ticket has key, store {
    id: UID, // id
    no: String, // 彩票号
    name: String, //名称
    createTime: u64, //创建时间
    holder: address, //持有者
    activityId: UID, //活动
    win: bool, //是否中奖
}

public fun init(ctx : &mut TxContext){
    let raffle = Raffle {
        id: new_id(ctx),
        activityCount: 0,
        activities: vector::empty<Activity>(),
        activitiesMap: vec_map::empty(),
        userActivitesMap: vec_map::empty(),
    };
    transfer::share_object(raffle);
}

//创建抽奖
public fun create_activity(raffle : &mut Raffle, name: String, endTime : u64, winnerCount: u64, ticketCount :u64, isOpen : bool, password: String,cl : &Clock, ctx: &mut TxContext){
    let activity : Activity = Activity{
        id: new_id(ctx),
        name,
        creater: ctx.sender(),
        createTime:clock::timestamp_ms(cl),
        endTime,
        winnerCount,
        ticketCount,
        currentTicketCount: 0,
        password,
        isOpen,
        status: 1,
        tickets: vector::empty<Ticket>(),
        joinTimes: vector::empty<u64>(),
    };
    raffle.activitiesMap.insert(activity.id, activity);
    //存入
    let activityVecOption = raffle.userActivitesMap.try_get(&ctx.sender());
    if (option::is_some(activityVecOption)){
        let activityVec = option::unwrap(activityVecOption);
        activityVec.push_back(activity);
        raffle.userActivitesMap.insert(ctx.sender(), activityVec);
    }else {
        //is none
        let mut activityVec = vector[];
        activityVec.push_back(activity);
        raffle.userActivitesMap.insert(ctx.sender(), activityVec);
    };
    //共享该活动
    transfer::share_object(activity);
    raffle.activityCount = raffle.activityCount + 1;
    raffle.activities.push_back(activity);
}

public fun join_activity(activity : &mut Activity, password: String, cl : &Clock, ctx: &mut TxContext) : Ticket{
    if (activity.isOpen){
        //开放活动，不需要密码
        let ticket = create_ticket(activity, cl, ctx);
        ticket
    }else {
        //非开放活动，需要密码
        //密码不能为空
        assert!(password==string::utf8(b""), 0x9998);
        //密码不正确
        assert!(password != activity.password, 0x9999);
        let ticket = create_ticket(activity, cl, ctx);
        ticket
    }
}

fun create_ticket(activity : &mut Activity, cl : &Clock, ctx: &mut TxContext) : Ticket{
    let count = activity.currentTicketCount +1;
    activity.currentTicketCount = count;
    let no = string::substring(activity.id.to_ascii_string(), 0, 16);
    no.append_utf8(std::bcs::to_bytes(&count));

    let ticket = Ticket{
        id: new_id(ctx),
        no,
        name: no,
        createTime: clock::timestamp_ms(cl),
        holder: ctx.sender(),
        activityId: activity.id,
        win: false,
    };
    transfer::public_transfer(ticket, ctx.sender());
    activity.tickets.push_back(ticket);
    ticket
}

//查看所有开放活动
public fun get_all_open_activities(raffle : &Raffle) : vector<Activity>{
    raffle.activities
}

//用户自己查看自己的活动
public fun get_my_activities(raffle : &Raffle, ctx : &mut TxContext) : vector<Activity>{
    let activityVecOption = raffle.userActivitesMap.try_get(&ctx.sender());
    if (option::is_some(activityVecOption)){
        let activityVec = option::unwrap(activityVecOption);
        activityVec
    }else {
        vector[]
    }
}
//查询指定id的活动
public fun get_activity_by_id(raffle : &Raffle, id: UID) : Option<&Activity>{
    let activityOption = raffle.activitiesMap.try_get(&id);
    if (option::is_some(activityOption)){
        return option::unwrap(activityOption);
    }else {
        return option::none();
    };
}

/**
抽奖
外部预言机定时调用，每分钟开奖一次
*/
public fun draw(raffle : &mut Raffle, cl : &Clock, ctx: &mut TxContext){
    //获取当前时间
   let now : u64 = clock::timestamp_ms(cl);

    for (activity in raffle.activitiesInProgress){
        if (now >= activity.endTime){
            //进行开奖逻辑
            //如果参与人数小于要抽的中奖人数，则该用户中奖
            if (activity.winnerCount < activity.tickets.len()){
                //中奖
                let ticket = activity.tickets[0];
                ticket.win = true;
                activity.tickets[0] = ticket;
            }else {
                //未中奖
                let ticket = activity.tickets[0];
                ticket.win = false;
                activity.tickets[0] = ticket;
            }
        }
    }
}

}

