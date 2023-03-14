// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "forge-std/console.sol";

contract Lottery {
    address public owner;

    modifier check_phase(){
        if(block.timestamp >= phase_start_time + BUY_PHASE && current_phase == 0){
            current_phase = 1;
        }
        _;
    }

    modifier check_reward(){
        _;
        if(total_winners == 0 && current_phase == 2){
            current_phase = 0;
            current_lottery += 1;
            phase_start_time = block.timestamp;
        }
    }

    mapping(uint256 => mapping(address => uint256)) lottery_ticket;
    mapping(uint256 => uint16) winning_numbers;

    uint constant BUY_PHASE = 24 hours;
    // 0 => SELL PHASE, 1 => DRAW PHASE, 2 => CALIM PHASE
    uint8 public current_phase;
    uint public current_lottery;
    uint public phase_start_time;

    mapping(uint =>address[]) private participants;
    uint public total_winners;
    mapping(address => bool) private reward_state;
    uint public reward;

    constructor() {
        current_lottery = 0;
        owner = msg.sender;
        phase_start_time = block.timestamp;
        current_phase = 0;
    }
    
    // 0.1 ETH 송금
    // 판매 페이즈에 하나의 lottery만 구매 가능
    // 판매 페이즈 종료시 lottery구매 불가능.
    function buy(uint16 x) public payable check_phase  {
        require(x < 65535);
        require(current_phase == 0, "NOT SELL PHASE");
        require(msg.value == 0.1 ether, "InSufficentFunds");
        require(lottery_ticket[current_lottery][msg.sender] == 0, "You already bought lottery");
        
        console.log(x);
        lottery_ticket[current_lottery][msg.sender] = x + 1;
        participants[current_lottery].push(msg.sender);
    }   

    function draw() public check_phase {
        require(current_phase == 1, "NOT DRAW PHASE");
        uint16 random_number = uint16(uint(keccak256(abi.encodePacked(block.difficulty))) % 65535);
        winning_numbers[current_lottery] = random_number;

        for(uint i = 0; i < participants[current_lottery].length; i++){
            if(lottery_ticket[current_lottery][msg.sender] == winning_numbers[current_lottery] + 1){
                total_winners += 1;
                reward_state[participants[current_lottery][i]] = true;
            }
        }
        if(total_winners > 0){
            reward = address(this).balance / total_winners;
        } else {
            reward = 0;
        }
        current_phase = 2;
    }

    // SELLING phase동안은 calim이 불가능함.
    // claim은 draw이후에 진행한다.
    function claim() public check_phase check_reward{
        require(current_phase == 2, "NOT CLAIM PHASE");

        if(reward_state[msg.sender] == false){
            return;
        }

        total_winners -= 1;
        reward_state[msg.sender] = false;

        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Transaction Fail");
    }

    function winningNumber() public returns(uint16){
        return winning_numbers[current_lottery];
    }

}