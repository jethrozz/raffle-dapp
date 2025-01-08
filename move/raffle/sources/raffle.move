
module raffle::raffle;

use std::string;
use std::string::String;
use sui::clock::{Self, Clock};
use sui::vec_map;
use sui::vec_map::VecMap;
use std::option::{Self};
use sui::bag::Bag;
use sui::balance;
use sui::balance::Balance;
use sui::coin::Coin;
use sui::sui::SUI;
use sui::random::{Self, Random, RandomGenerator};



public struct Raffle has key , store{
    id: UID,
    activities: vector<Activity>, //已经产生的活动
    activitiesMap : VecMap<UID, Activity>, //活动id
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
    password: String, //活动密码，非开放活动需要输入密码
    isOpen: bool, //是否开放
    status: u8, //活动状态 0:已创建 1:进行中 2:已开奖
    tickets: vector<Ticket>, //已经产生的抽奖券
    //奖品 可以是NFT或者SUI，只支持这两个
    nftIds : vector<UID>,
    token: Balance<SUI>,
    drawer: address, //开奖人
    winners: vector<address>, //中奖人
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

/**
事件定以
*/
// 定义一个抽奖事件
public struct RaffleEvent has store {
    activity_id: u64,       // 活动ID
    winner: address,        // 中奖者地址
    prize_amount: u64,      // 奖品数量
}

public fun init(ctx : &mut TxContext){
    let raffle = Raffle {
        id: new_id(ctx),
        activities: vector::empty<Activity>(),
        activitiesMap: vec_map::empty(),
        activitiesInProgress: vector::empty<Activity>(),
        userActivitesMap: vec_map::empty(),
    };
    transfer::share_object(raffle);
}

//创建抽奖
public fun create_activity(raffle : &mut Raffle, name: String, endTime : u64, winnerCount: u64, isOpen : bool, password: String, cl : &Clock, ctx: &mut TxContext){
    //最多抽99个address
    assert!(winnerCount<100, 0x10002);
    let activity : Activity = Activity{
        id:  object::new(ctx),
        name,
        creater: ctx.sender(),
        createTime:clock::timestamp_ms(cl),
        endTime,
        winnerCount,
        password,
        isOpen,
        status: 1,
        tickets: vector::empty<Ticket>(),
        nftIds: vector::empty<UID>(),
        token : balance::zero(),
        drawer: @0x0,
        winners: vector::empty<address>(),
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
    raffle.activities.push_back(activity);
}
public fun start_activity(raffle : &mut Raffle, activity : &mut Activity, ctx: &mut TxContext){
    //活动状态为0才能开始
    assert!(activity.status == 0, 0x10003);
    //token值要大于0    或者nft 数量要等于winnerCoung才能开始
    assert!(activity.nftIds.length() == activity.winnerCount || activity.token.value() > 0, 0x10004);
    //设置状态为进行中
    activity.status = 1;
    raffle.activitiesInProgress.push_back(activity);
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
    let count = activity.tickets.length();
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



/*
* 向 抽奖活动中add sui
  至少满足 99 个单位
*/
public entry fun add_sui(activity : &mut Activity, coin : Coin<SUI>, _: &mut TxContext){
    //至少满足99个单位
    assert!(coin::value_of(coin) >= 99, 0x10001);
    let balance = coin::into_balance(coin);
    activity.token.join(balance);
}

public entry fun add_nft<T: key + store>(activity : &mut Activity, nft: T, _: &mut TxContext){
    //nft 交易给合约
    transfer::public_transfer(nft, object::uid_to_address(&activity.id));
    activity.nftIds.push_back(nft.id());
}

//查看所有活动
public fun get_all_open_activities(raffle : &Raffle) : vector<Activity>{
    raffle.activitiesInProgress
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
大家都可以来开奖
*/
public fun draw(raffle : &mut Raffle, activity : &mut Activity, rand: &Random, cl : &Clock, ctx: &mut TxContext){
    //

    //获取当前时间
    let now : u64 = clock::timestamp_ms(cl);
    //未到开奖时间
    assert!(now >= activity.endTime, 0x9997);
    //不是进行中的状态，只有进行中的状态才能进行开奖
    assert!(activity.status==1, 0x9998);


    activity.drawer = ctx.sender();
    //进行开奖逻辑
    //如果参与人数小于要抽的中奖人数，则参与抽奖的用户中奖
    let winners = vector::empty<Ticket>();
    if (activity.winnerCount <= activity.tickets.length()){
        //中奖
        for (ticket in activity.tickets){
            ticket.win = true;
            winners.push_back(ticket);
        };
    }else {
        //随机抽奖
        let mut remaining_participants = vector::empty<Ticket>();
        //复制所有参与者
        let pIndex = 0;
        while (pIndex < vector::length(&activity.tickets)) {
            let participant = *vector::borrow(&activity.tickets, pIndex);
            remaining_participants.push_back(participant);
            pIndex = pIndex + 1;
        };

        let mut generator: RandomGenerator = random::new_generator(rand, ctx);
        let count = activity.winnerCount;
        let mut i=0;
        while (i < count){
            //生成一个索引下标
            let index = random::generate_u64_in_range(&mut generator, 0, remaining_participants.length());
            //第i个中奖者
            let winner = *vector::borrow(&remaining_participants, index);
            winner.win = true;
            vector::push_back(&mut winners, winner);
            remaining_participants.remove(index);
            //Get the next block of random bytes.
            generator.derive_next_block();
            i = i+1;
        };
    };


    // 如果奖品是token
    if (activity.token.value() != 0){
        //把token 分成 winnerCount份
        let token_per_winner = activity.token.value() / activity.winnerCount;
        for (winner in winners){
            //发奖
            let split = activity.token.split(token_per_winner);
            //转换成coin
            let coin = coin::from_balance(split, ctx);
            //发送给中奖者
            transfer::public_transfer(coin, winner);
        };
    };
    // 如果奖品是nft
    if(activity.nftIds.length() != 0){
        let i : u64 = 0;
        for (winner in winners){
            //发奖
            let nft = vector::borrow(&activity.nftIds, i);
            activity.nftIds.remove(i);
            //转发给中奖者
            transfer::public_transfer(nft, winner);
        };
    };

    activity.status = 2;
    let removeIndex = raffle.activitiesInProgress.index_of(activity);
    raffle.activitiesInProgress.remove(removeIndex);
}

// 将 u8 数字转换为字符串（优化版）
fun u8_to_string(value: u8): String {
    let result = string::utf8(b""); // 创建一个空字符串

    // 处理值为 0 的特殊情况
    if (value == 0) {
        string::append_utf8(&mut result, b"0");
        return result;
    };

    // 拆解百位、十位、个位
    let hundreds = value / 100;
    let tens = (value % 100) / 10;
    let ones = value % 10;

    // 将每一位数字转换为字符并拼接到字符串中
    if (hundreds > 0) {
        string::push_char(&mut result, digit_to_char(hundreds));
    };
    if (tens > 0 || hundreds > 0) {
        string::push_char(&mut result, digit_to_char(tens));
    };
    string::push_char(&mut result, digit_to_char(ones));

    result
}

// 将数字（0-9）转换为对应的字符
fun digit_to_char(digit: u8): u8 {
    assert!(digit <= 9, 0x1001); // 确保数字在 0-9 范围内
    (digit + 48) // ASCII 码中 '0' 是 48
}

// 拼接字符串和数字
fun concat_string_and_number(str: String, num: u8): String {
    let num_str = u8_to_string(num); // 将数字转换为字符串
    string::append(&mut str, num_str); // 拼接字符串和数字字符串
    str
}

}

