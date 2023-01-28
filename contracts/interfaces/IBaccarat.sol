//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IBaccarat{
    enum BetType {
        Banker,
        Player,
        Tie,
        BankerPair,
        PlayerPair,
        SuperSix
    }

    struct LayoutAction {
        address player;
        address token;
        uint256 amount;
        uint256 betType;
    }

    struct Result {
        uint16 cursor;      // 0 ..< 416
        uint8 bankerPoints; // 0 ..< 10
        uint8 playerPoints; // 0 ..< 10
        uint8 bankerHands1; // 1 ... 52, 0 = no card
        uint8 bankerHands2; // 1 ... 52, 0 = no card
        uint8 bankerHands3; // 1 ... 52, 0 = no card
        uint8 playerHands1; // 1 ... 52, 0 = no card
        uint8 playerHands2; // 1 ... 52, 0 = no card
        uint8 playerHands3; // 1 ... 52, 0 = no card
    }

    event Action(address indexed _player, address indexed _token, uint256 _amount, uint256 _betType);
    event Settle(Result result);
    event Shuffle(uint256 _nonce);
    event Burning(uint256 _amount);

    // Returns the shuffled deck of cards
    function shuffle(uint256 _nonce) external;

    // @notice player action
    // @param _token betting token address
    // @param _amount betting amount
    // @param _betType betting type, 0 = banker, 1 = player, 2 = tie, 3 = banker pair, 4 = player pair
    function action(address _token, uint256 _amount, uint256 _betType) payable external;

    // @notice play the game and settle the bet
    function settle(uint256 _nonce) external;
}