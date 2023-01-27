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

    struct Card {
        uint8 rank; // 1-13, 1 is Ace, 11 is Jack, 12 is Queen, 13 is King
        uint8 suit; // 1-4, 1 = spades, 2 = hearts, 3 = diamonds, 4 = clubs
    }

    struct LayoutAction {
        address player;
        address token;
        uint256 amount;
        uint256 betType;
    }

    struct ActionResult {
        bool banker;
        bool player;
        bool tie;
        bool bankerPair;
        bool playerPair;
        bool superSix;
    }

    event Action(uint256 indexed _cursor, address indexed _player, address _token, uint256 _amount, uint256 _betType);
    event Settle(uint256 indexed _cursor, ActionResult result, Card[] bankerHands, Card[] playerHands);
    event Shuffle(uint256 _cursor, uint256 _nonce);
    event Burning(uint256 _amount);

    // Returns the shuffled deck of cards
    function shuffle(uint256 _nonce) external;

    // @notice player action
    // @param _token betting token address
    // @param _amount betting amount
    // @param _betType betting type, 0 = banker, 1 = player, 2 = tie, 3 = banker pair, 4 = player pair
    function action(address _token, uint256 _amount, uint256 _betType) payable external;

    // @notice play the game and settle the bet
    function settle(uint256 nonce) external;
}