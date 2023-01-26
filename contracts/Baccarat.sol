//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBaccarat.sol";

contract Baccarat is IBaccarat, Ownable {
    Card[] private _shoe;
    uint256 private _cursor;

    LayoutAction[] private _layout;

    // player address => token address => amount
    // user can withdraw Cheques
    mapping(address => mapping(address => uint256)) private _cheques;

    Card[] private _playerHands;
    Card[] private _bankerHands;

    constructor() {
        // push 8 decks of cards into shoe
        for (uint256 i = 0; i < 8; i++) {
            for (uint256 j = 0; j < 52; j++) {
                Card memory card;
                card.suit = uint8(j / 13) + 1;
                card.rank = uint8(j % 13) + 1;
                _shoe.push(card);
            }
        }
    }

    // @notice player action
    // @param _token betting token address
    // @param _amount betting amount
    // @param _betType betting type, 0 = banker, 1 = player, 2 = tie, 3 = banker pair, 4 = player pair, 5 = banker super six, 6 = player super six
    function action(address _token, uint256 _amount, uint256 _betType) payable external {
        uint256 cheques = _cheques[msg.sender][_token];
        if (_token == address(0)) {
            if (cheques >= _amount) {
                _cheques[msg.sender][_token] = cheques - _amount;
            } else {
                _cheques[msg.sender][_token] = 0;
                require(msg.value == _amount - cheques, "Baccarat: insufficient ether");
            }
        } else {
            if (cheques >= _amount) {
                _cheques[msg.sender][_token] = cheques - _amount;
            } else {
                _cheques[msg.sender][_token] = 0;
                require(IERC20(_token).transferFrom(msg.sender, address(this), _amount - cheques), "Baccarat: insufficient token");
            }
        }

        // check if already bet, if yes, add amount
        bool bet = false;
        for (uint256 i = 0; i < _layout.length; i++) {
            if (_layout[i].player == msg.sender && _layout[i].token == _token && _layout[i].betType == _betType) {
                _layout[i].amount += _amount;
                bet = true;
                break;
            }
        }
        if (!bet) {
            _layout.push(LayoutAction(msg.sender, _token, _amount, _betType));
        }

        emit Action(_token, _amount, _betType);
    }

    // @notice play the game and settle the bet
    // @param nonce random number, anyone can call this function
    function settle(uint256 nonce) external {
        require(_checkAction(), "Baccarat: need both bet banker and player");

        // delete playerHands and bankerHands
        delete _playerHands;
        delete _bankerHands;

        uint256 seed = uint256(keccak256(abi.encodePacked(
                block.timestamp,
                block.difficulty,
                _cursor,
                nonce
            )));
        if (_shoe.length - _cursor < 6) {
            // shuffle
            _cursor = 0;
            _shuffle(seed);
            _burning();
        } else {
            // re-shuffle the Shoe after cursor
            _shuffle(seed);
        }

        ActionResult memory result;

        // player hands
        _playerHands.push(_shoe[_cursor]);
        _bankerHands.push(_shoe[_cursor + 1]);
        _playerHands.push(_shoe[_cursor + 2]);
        _bankerHands.push(_shoe[_cursor + 3]);
        _cursor += 4;

        // calculate hands value
        uint256 playerHandsValue = _getPoint(_getPoint(_playerHands[0].rank) + _getPoint(_playerHands[1].rank));
        uint256 bankerHandsValue = _getPoint(_getPoint(_bankerHands[0].rank) + _getPoint(_bankerHands[1].rank));

        // if not Natural
        if (playerHandsValue < 8 && bankerHandsValue < 8) {
            // if player hands value is less than 6, draw a third card
            if (playerHandsValue < 6) {
                _playerHands.push(_shoe[_cursor]);
                playerHandsValue = _getPoint(playerHandsValue + _getPoint(_playerHands[2].rank));
                _cursor += 1;
            }

            // if player no need draw a third card, banker < 6, banker need draw a third card
            if (_playerHands.length == 2 && bankerHandsValue < 6) {
                // draw
                _bankerHands.push(_shoe[_cursor]);
                bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(_bankerHands[2].rank));
                _cursor += 1;
            }

            if (_playerHands.length == 3) {
                if (bankerHandsValue <= 2) {
                    // draw
                    _bankerHands.push(_shoe[_cursor]);
                    bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(_bankerHands[2].rank));
                    _cursor += 1;
                }
                if (bankerHandsValue == 3 && _getPoint(_playerHands[2].rank) != 8) {
                    // draw
                    _bankerHands.push(_shoe[_cursor]);
                    bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(_bankerHands[2].rank));
                    _cursor += 1;
                }
                if (bankerHandsValue == 4 && _getPoint(_playerHands[2].rank) >= 2 && _getPoint(_playerHands[2].rank) <= 7) {
                    // draw
                    _bankerHands.push(_shoe[_cursor]);
                    bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(_bankerHands[2].rank));
                    _cursor += 1;
                }
                if (bankerHandsValue == 5 && _getPoint(_playerHands[2].rank) >= 4 && _getPoint(_playerHands[2].rank) <= 7) {
                    // draw
                    _bankerHands.push(_shoe[_cursor]);
                    bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(_bankerHands[2].rank));
                    _cursor += 1;
                }
                if (bankerHandsValue == 6 && _getPoint(_playerHands[2].rank) >= 6 && _getPoint(_playerHands[2].rank) <= 7) {
                    // draw
                    _bankerHands.push(_shoe[_cursor]);
                    bankerHandsValue = _getPoint(bankerHandsValue + _getPoint(_bankerHands[2].rank));
                    _cursor += 1;
                }
            }
        }

        // settle the bet
        if (playerHandsValue < bankerHandsValue) {
            result.banker = true;
            for (uint256 i = 0; i < _layout.length; i++) {
                // banker win, 1 : 0.95
                if (_layout[i].betType == uint256(BetType.Banker)) {
                    _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 195 / 100);
                }
                if (_layout[i].betType == uint256(BetType.SuperSix) && bankerHandsValue == 6) {
                    result.superSix = true;
                    if (_bankerHands.length == 3) {
                        // banker win with 3 cards, super six, 1 : 20
                        _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 21);
                    } else {
                        // banker win with 2 cards, super six, 1 : 12
                        _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 13);
                    }
                }
            }
        } else if (playerHandsValue > bankerHandsValue) {
            // player win, 1 : 1
            result.player = true;
            for (uint256 i = 0; i < _layout.length; i++) {
                if (_layout[i].betType == uint256(BetType.Player)) {
                    _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 2);
                }
            }
        } else {
            // tie, 1 : 8
            result.tie = true;
            for (uint256 i = 0; i < _layout.length; i++) {
                if (_layout[i].betType == uint256(BetType.Tie)) {
                    _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 9);
                }
            }
        }

        // banker pair, 1 : 11
        if (_bankerHands[0].rank == _bankerHands[1].rank) {
            result.bankerPair = true;
            for (uint256 i = 0; i < _layout.length; i++) {
                if (_layout[i].betType == uint256(BetType.BankerPair)) {
                    _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 12);
                }
            }
        }

        // player pair, 1 : 11
        if (_playerHands[0].rank == _playerHands[1].rank) {
            result.playerPair = true;
            for (uint256 i = 0; i < _layout.length; i++) {
                if (_layout[i].betType == uint256(BetType.PlayerPair)) {
                    _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 12);
                }
            }
        }

        emit Settle(result, _bankerHands, _playerHands);
    }

    // @notice withdraw the token from contract
    // @param _token the token address
    // @param _amount the amount of token
    function withdraw(address _token, uint256 _amount) external {
        require(_cheques[msg.sender][_token] >= _amount, "not enough credit");
        _cheques[msg.sender][_token] -= _amount;
        _safeTransfer(_token, msg.sender, _amount);
    }

    function withdrawOnlyOwner(address _token, uint256 _amount) external onlyOwner {
        _safeTransfer(_token, msg.sender, _amount);
    }

    // @notice get the point of the card
    // @param _rank the rank of the card
    function _getPoint(uint256 _rank) internal pure returns (uint256) {
        if (_rank >= 10) {
            return 0;
        } else {
            return _rank;
        }
    }

    // @dev transfer the token, or record the cheque
    function _safeTransfer(address _token, address _to, uint256 _amount) internal {
        if (_token == address(0)) {
            if (address(this).balance >= _amount) {
                payable(_to).transfer(_amount);
            } else {
                _cheques[_to][_token] += _amount;
            }
        } else {
            if (IERC20(_token).balanceOf(address(this)) >= _amount) {
                IERC20(_token).transfer(_to, _amount);
            } else {
                _cheques[_to][_token] += _amount;
            }
        }
    }

    // @dev check whether can be settle, only can be settle when have banker and player
    function _checkAction() internal view returns (bool) {
        // need both have banker and player betting
        bool banker = false;
        bool player = false;
        for (uint256 i = 0; i < _layout.length; i++) {
            if (_layout[i].betType == 0) {
                banker = true;
            } else if (_layout[i].betType == 1) {
                player = true;
            }
        }

        return banker && player;
    }

    // burn some cards after init shuffle
    function _burning() internal {
        uint256 point = _getPoint(_shoe[_cursor].rank);
        if (point <= 7) {
            _cursor += 3;
        } else {
            _cursor += 2;
        }

        emit Burning(point);
    }

    // @notice Use Knuth shuffle algorithm to shuffle the cards
    // @param _seed random seed, from business data and block data
    function shuffle(uint256 _seed) external {
        _shuffle(_seed);
    }

    function _shuffle(uint256 _nonce) internal {
        uint256 n = _shoe.length;
        for (uint256 i = _cursor; i < n; i++) {
            // Pseudo random number between i and n-1
            uint256 j = i + uint256(keccak256(abi.encodePacked(i, _nonce))) % (n - i);
            // swap i and j
            Card memory temp = _shoe[i];
            _shoe[i] = _shoe[j];
            _shoe[j] = temp;
        }
        emit Shuffle(_cursor, _nonce);
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        while (_i != 0) {
            bstr[k--] = bytes1(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

    // @notice get the card from the shoe
    // @param cursor start begin
    // @param count the number of card
    function cardsOf(uint256 cursor, uint256 count) external view returns (CardView[] memory) {
        require((cursor + count) <= _shoe.length, "not enough cards");
        CardView[] memory cards = new CardView[](count);
        for (uint256 i = 0; i < count; i++) {
            uint8 suit = _shoe[cursor + i].suit;
            uint8 rank = _shoe[cursor + i].rank;
            string memory suitStr;
            string memory rankStr;
            if (suit == 0) {
                suitStr = "Spade";
            } else if (suit == 1) {
                suitStr = "Heart";
            } else if (suit == 2) {
                suitStr = "Club";
            } else if (suit == 3) {
                suitStr = "Diamond";
            }
            if (rank == 1) {
                rankStr = "A";
            } else if (rank == 11) {
                rankStr = "J";
            } else if (rank == 12) {
                rankStr = "Q";
            } else if (rank == 13) {
                rankStr = "K";
            } else {
                rankStr = uint2str(rank);
            }
            cards[i] = CardView(suitStr, rankStr);
        }
        return cards;
    }

    // @notice get the actions at the current layout
    function layout() external view returns (LayoutAction[] memory) {
        return _layout;
    }

    // @notice get current cursor
    function readCursor() external view returns (uint256) {
        return _cursor;
    }

    // @notice get cheque balance of the user
    function chequesOf(address _player, address _token) external view returns (uint256) {
        return _cheques[_player][_token];
    }
}