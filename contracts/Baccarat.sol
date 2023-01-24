//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/IBaccarat.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Baccarat is IBaccarat, Ownable {
    Card[] public Shoe;
    uint256 public ShoeCursor;

    BettingView[] public BettingViews;

    // player address => token address => amount
    mapping(address => mapping(address => uint256)) public Credit;

    Card[] private playerHands;
    Card[] private bankerHands;

    constructor() {
        // push 8 decks of cards into shoe
        for (uint256 i = 0; i < 8; i++) {
            for (uint256 j = 0; j < 52; j++) {
                Card memory card;
                card.suit = uint8(j / 13) + 1;
                card.rank = uint8(j % 13) + 1;
                Shoe.push(card);
            }
        }
    }

    // @notice Use Knuth shuffle algorithm to shuffle the cards
    // @param _seed random seed, from business data and block data
    function shuffle(uint256 _seed) public {
        uint256 n = Shoe.length;
        for (uint256 i = ShoeCursor; i < n; i++) {
            // Pseudo random number between i and n-1
            uint256 j = i + uint256(keccak256(abi.encodePacked(i, _seed))) % (n - i);
            // swap i and j
            Card memory temp = Shoe[i];
            Shoe[i] = Shoe[j];
            Shoe[j] = temp;
        }
    }

    // @notice player betting
    // @param _token betting token address
    // @param _amount betting amount
    // @param _betType betting type, 0 = banker, 1 = player, 2 = tie, 3 = banker pair, 4 = player pair, 5 = banker super six, 6 = player super six
    function betting(address _token, uint256 _amount, uint256 _betType) payable external {
        if (_token == address(0)) {
            require(msg.value >= _amount, "Baccarat: betting amount is not enough");
        } else {
            require(IERC20(_token).transferFrom(msg.sender, address(this), _amount), "Baccarat: ERC20 transferFrom failed");
        }

        // check if already bet, if yes, add amount
        bool bet = false;
        for (uint256 i = 0; i < BettingViews.length; i++) {
            if (BettingViews[i].player == msg.sender && BettingViews[i].token == _token && BettingViews[i].betType == _betType) {
                BettingViews[i].amount += _amount;
                bet = true;
                break;
            }
        }
        if (!bet) {
            BettingViews.push(BettingView(msg.sender, _token, _amount, _betType));
        }
    }

    function _getPoint(uint256 _rank) internal pure returns (uint256) {
        if (_rank >= 10) {
            return 0;
        } else {
            return _rank;
        }
    }

    function _safeTransfer(address _token, address _to, uint256 _amount) internal {
        if (_token == address(0)) {
            if (address(this).balance >= _amount) {
                payable(_to).transfer(_amount);
            } else {
                Credit[_to][_token] += _amount;
            }
        } else {
            if (IERC20(_token).balanceOf(address(this)) >= _amount) {
                IERC20(_token).transfer(_to, _amount);
            } else {
                Credit[_to][_token] += _amount;
            }
        }
    }

    function _hasPair(Card[] memory _cards) internal pure returns (bool) {
        for (uint256 i = 0; i < _cards.length; i++) {
            for (uint256 j = i + 1; j < _cards.length; j++) {
                if (_cards[i].rank == _cards[j].rank) {
                    return true;
                }
            }
        }
        return false;
    }

    function _canSettle() internal view returns (bool) {
        // need both have banker and player betting
        bool banker = false;
        bool player = false;
        for (uint256 i = 0; i < BettingViews.length; i++) {
            if (BettingViews[i].betType == 0) {
                banker = true;
            } else if (BettingViews[i].betType == 1) {
                player = true;
            }
        }

        return banker && player;
    }

    function settle(uint256 nonce) external {
        require(_canSettle(), "Baccarat: need both bet banker and player");

        // delete playerHands and bankerHands
        delete playerHands;
        delete bankerHands;

        uint256 seed = uint256(keccak256(abi.encodePacked(
                block.timestamp,
                block.difficulty,
                ShoeCursor,
                nonce
            )));
        if (Shoe.length - ShoeCursor < 6) {
            // shuffle
            ShoeCursor = 0;
            shuffle(seed);
        } else {
            // re-shuffle the Shoe after cursor
            shuffle(seed);
        }

        // player hands
        playerHands.push(Shoe[ShoeCursor]);
        bankerHands.push(Shoe[ShoeCursor + 1]);
        playerHands.push(Shoe[ShoeCursor + 2]);
        bankerHands.push(Shoe[ShoeCursor + 3]);
        ShoeCursor += 4;

        // calculate hands value
        uint256 playerHandsValue = _getPoint(_getPoint(playerHands[0].rank) + _getPoint(playerHands[1].rank));
        uint256 bankerHandsValue = _getPoint(_getPoint(bankerHands[0].rank) + _getPoint(bankerHands[1].rank));

        // if not Natural
        if (playerHandsValue < 8 && bankerHandsValue < 8) {
            // if player hands value is less than 6, draw a third card
            if (playerHandsValue < 6) {
                playerHands.push(Shoe[ShoeCursor]);
                playerHandsValue = _getPoint(playerHandsValue + _getPoint(playerHands[2].rank));
                ShoeCursor += 1;
            }

            // if player no need draw a third card, banker < 6, banker need draw a third card
            if (playerHands.length == 2 && bankerHandsValue < 6) {
                // draw
                bankerHands.push(Shoe[ShoeCursor]);
                bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(bankerHands[2].rank));
                ShoeCursor += 1;
            }

            if (playerHands.length == 3) {
                if (bankerHandsValue <= 2) {
                    // draw
                    bankerHands.push(Shoe[ShoeCursor]);
                    bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(bankerHands[2].rank));
                    ShoeCursor += 1;
                }
                if (bankerHandsValue == 3 && _getPoint(playerHands[2].rank) != 8) {
                    // draw
                    bankerHands.push(Shoe[ShoeCursor]);
                    bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(bankerHands[2].rank));
                    ShoeCursor += 1;
                }
                if (bankerHandsValue == 4 && _getPoint(playerHands[2].rank) >= 2 && _getPoint(playerHands[2].rank) <= 7) {
                    // draw
                    bankerHands.push(Shoe[ShoeCursor]);
                    bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(bankerHands[2].rank));
                    ShoeCursor += 1;
                }
                if (bankerHandsValue == 5 && _getPoint(playerHands[2].rank) >= 4 && _getPoint(playerHands[2].rank) <= 7) {
                    // draw
                    bankerHands.push(Shoe[ShoeCursor]);
                    bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(bankerHands[2].rank));
                    ShoeCursor += 1;
                }
                if (bankerHandsValue == 6 && _getPoint(playerHands[2].rank) >= 6 && _getPoint(playerHands[2].rank) <= 7) {
                    // draw
                    bankerHands.push(Shoe[ShoeCursor]);
                    bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(bankerHands[2].rank));
                    ShoeCursor += 1;
                }
            }
        }

        // settle the bet
        if (playerHandsValue < bankerHandsValue) {
            for (uint256 i = 0; i < BettingViews.length; i++) {
                // banker win, 1 : 0.95
                if (BettingViews[i].betType == uint256(BetType.Banker)) {
                    _safeTransfer(BettingViews[i].token, BettingViews[i].player, BettingViews[i].amount * 195 / 100);
                    _safeTransfer(BettingViews[i].token, owner(), BettingViews[i].amount * 5 / 100);
                }
                // banker win and super six, 1 : 20
                if (BettingViews[i].betType == uint256(BetType.BankerSuperSix) && bankerHandsValue == 6) {
                    if (bankerHands.length == 3) {
                        _safeTransfer(BettingViews[i].token, BettingViews[i].player, BettingViews[i].amount * 21);
                    } else {
                        _safeTransfer(BettingViews[i].token, BettingViews[i].player, BettingViews[i].amount * 13);
                    }
                }
            }
        } else if (playerHandsValue > bankerHandsValue) {
            // player win, 1 : 1
            for (uint256 i = 0; i < BettingViews.length; i++) {
                if (BettingViews[i].betType == uint256(BetType.Player)) {
                    _safeTransfer(BettingViews[i].token, BettingViews[i].player, BettingViews[i].amount * 2);
                }
                // player win and super six, 1 : 20
                if (BettingViews[i].betType == uint256(BetType.PlayerSuperSix) && playerHandsValue == 6) {
                    if (playerHands.length == 3) {
                        _safeTransfer(BettingViews[i].token, BettingViews[i].player, BettingViews[i].amount * 21);
                    } else {
                        _safeTransfer(BettingViews[i].token, BettingViews[i].player, BettingViews[i].amount * 13);
                    }
                }
            }
        } else {
            // tie, 1 : 8
            for (uint256 i = 0; i < BettingViews.length; i++) {
                if (BettingViews[i].betType == uint256(BetType.Tie)) {
                    _safeTransfer(BettingViews[i].token, BettingViews[i].player, BettingViews[i].amount * 9);
                }
            }
        }

        // check pair
        if (_hasPair(bankerHands)) {
            // player pair, 1 : 11
            for (uint256 i = 0; i < BettingViews.length; i++) {
                if (BettingViews[i].betType == uint256(BetType.BankerPair)) {
                    _safeTransfer(BettingViews[i].token, BettingViews[i].player, BettingViews[i].amount * 12);
                }
            }
        }

        if (_hasPair(playerHands)) {
            // player pair, 1 : 11
            for (uint256 i = 0; i < BettingViews.length; i++) {
                if (BettingViews[i].betType == uint256(BetType.PlayerPair)) {
                    _safeTransfer(BettingViews[i].token, BettingViews[i].player, BettingViews[i].amount * 12);
                }
            }
        }
    }

    function withdraw(address _token, uint256 _amount) external {
        require(Credit[msg.sender][_token] >= _amount, "not enough credit");
        Credit[msg.sender][_token] -= _amount;
        _safeTransfer(_token, msg.sender, _amount);
    }
}