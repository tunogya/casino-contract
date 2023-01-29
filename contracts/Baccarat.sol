//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBaccarat.sol";

contract Baccarat is IBaccarat, Ownable {
    // @notice use 1...52 as card id to represent one suit of cards
    // if x % 13 == 1, x represents A
    // ...
    // if x % 13 == 0, x represents K
    // if x % 4 == 0, x represents spade
    // if x % 4 == 1, x represents heart
    // if x % 4 == 2, x represents club
    // if x % 4 == 3, x represents diamond
    uint8[] private _shoe;

    // @notice cursor is an important flag in shoe, it represents the index of next card to distribute
    // if index of shoe < cursor, this card will not be changed any more
    // if index of shoe >= cursor, this card will be changed when shuffle
    uint256 private _cursor;

    // @notice it only saves the current betting layout, it will be cleared when settle
    LayoutAction[] private _layout;

    // @notice player address => token address => amount
    mapping(address => mapping(address => uint256)) private _cheques;

    // @notice it saves the result of each settle, when cursor = 0, it will be cleared
    Result[] private _results;

    constructor() {
        for (uint256 i = 0; i < 8; i++) {
            for (uint8 j = 1; j <= 52; j++) {
                _shoe.push(j);
            }
        }
    }

    // @notice player action
    // @param _token betting token address
    // @param _amount betting amount
    // @param _betType betting type, 0 = banker, 1 = player, 2 = tie, 3 = banker pair, 4 = player pair, 5 = banker super six, 6 = player super six
    function action(address _token, uint256 _amount, uint256 _betType) payable external {
        require(_cursor > 0, "Baccarat: game not started, need to shuffle first");

        uint256 cheques = _cheques[msg.sender][_token];
        if (_token == address(0)) {
            if (cheques >= _amount) {
                _cheques[msg.sender][_token] = cheques - _amount;
            } else {
                _cheques[msg.sender][_token] = 0;
                require(msg.value >= _amount - cheques, "Baccarat: insufficient ether");
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

        emit Action(msg.sender, _token, _amount, _betType);
    }

    // @notice play the game and settle the bet
    // @param nonce random number, anyone can call this function
    function settle(uint256 nonce) external {
        require(_checkAction(), "Baccarat: need both bet banker and player");

        Result memory result;
        result.cursor = uint16(_cursor);

        nonce = uint256(keccak256(abi.encodePacked(
                block.timestamp,
                block.difficulty,
                _cursor,
                nonce
            )));
        // if shoe is less than 6 cards, can not play
        if (_shoe.length - _cursor < 6) {
            // set cursor to 0
            _cursor = 0;
            // delete _settleResults;
            delete _results;
        }
        // shuffle 6 cards
        _shuffle(nonce, _cursor + 6);

        // player hands
        result.playerHands1 = _shoe[_cursor];
        result.bankerHands1 = _shoe[_cursor + 1];
        result.playerHands2 = _shoe[_cursor + 2];
        result.bankerHands2 = _shoe[_cursor + 3];
        _cursor += 4;

        // calculate hands value
        result.bankerPoints = (_getPoint(result.bankerHands1) + _getPoint(result.bankerHands2)) % 10;
        result.playerPoints = (_getPoint(result.playerHands1) + _getPoint(result.playerHands2)) % 10;

        // if not Natural
        if (result.playerPoints < 8 && result.bankerPoints < 8) {
            // if player hands value is less than 6, draw a third card
            if (result.playerPoints < 6) {
                result.playerHands3 = _shoe[_cursor];
                result.playerPoints = (result.playerPoints + _getPoint(result.playerHands3)) % 10;
                _cursor += 1;
            }

            // if player no need draw a third card, banker < 6, banker need draw a third card
            if (result.playerHands3 == 0 && result.bankerPoints < 6) {
                result.bankerHands3 = _shoe[_cursor];
                result.bankerPoints = (result.bankerPoints + _getPoint(result.bankerHands3)) % 10;
                _cursor += 1;
            }

            if (result.playerHands3 > 0) {
                if (result.bankerPoints <= 2) {
                    result.bankerHands3 = _shoe[_cursor];
                    result.bankerPoints = (result.bankerPoints + _getPoint(result.bankerHands3)) % 10;
                    _cursor += 1;
                } else if (result.bankerPoints == 3 && _getPoint(result.playerHands3) != 8) {
                    result.bankerHands3 = _shoe[_cursor];
                    result.bankerPoints = (result.bankerPoints + _getPoint(result.bankerHands3)) % 10;
                    _cursor += 1;
                } else if (result.bankerPoints == 4 && _getPoint(result.playerHands3) >= 2 && _getPoint(result.playerHands3) <= 7) {
                    result.bankerHands3 = _shoe[_cursor];
                    result.bankerPoints = (result.bankerPoints + _getPoint(result.bankerHands3)) % 10;
                    _cursor += 1;
                } else if (result.bankerPoints == 5 && _getPoint(result.playerHands3) >= 4 && _getPoint(result.playerHands3) <= 7) {
                    result.bankerHands3 = _shoe[_cursor];
                    result.bankerPoints = (result.bankerPoints + _getPoint(result.bankerHands3)) % 10;
                    _cursor += 1;
                } else if (result.bankerPoints == 6 && _getPoint(result.playerHands3) >= 6 && _getPoint(result.playerHands3) <= 7) {
                    result.bankerHands3 = _shoe[_cursor];
                    result.bankerPoints = (result.bankerPoints + _getPoint(result.bankerHands3)) % 10;
                    _cursor += 1;
                }
            }
        }

        // settle the bet
        if (result.playerPoints < result.bankerPoints) {
            for (uint256 i = 0; i < _layout.length; i++) {
                // banker win, 1 : 0.95
                if (_layout[i].betType == uint256(BetType.Banker)) {
                    _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 195 / 100);
                }
                if (_layout[i].betType == uint256(BetType.SuperSix) && result.bankerPoints == 6) {
                    if (result.bankerHands3 > 0) {
                        // banker win with 3 cards, super six, 1 : 20
                        _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 21);
                    } else {
                        // banker win with 2 cards, super six, 1 : 12
                        _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 13);
                    }
                }
            }
        } else if (result.playerPoints > result.bankerPoints) {
            // player win, 1 : 1
            for (uint256 i = 0; i < _layout.length; i++) {
                if (_layout[i].betType == uint256(BetType.Player)) {
                    _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 2);
                }
            }
        } else {
            // tie, 1 : 8
            for (uint256 i = 0; i < _layout.length; i++) {
                if (_layout[i].betType == uint256(BetType.Tie)) {
                    _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 9);
                }
            }
        }

        // banker pair, 1 : 11
        if (result.bankerHands1 % 13 == result.bankerHands2 % 13) {
            for (uint256 i = 0; i < _layout.length; i++) {
                if (_layout[i].betType == uint256(BetType.BankerPair)) {
                    _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 12);
                }
            }
        }

        // player pair, 1 : 11
        if (result.playerHands1 % 13 == result.playerHands2 % 13) {
            for (uint256 i = 0; i < _layout.length; i++) {
                if (_layout[i].betType == uint256(BetType.PlayerPair)) {
                    _safeTransfer(_layout[i].token, _layout[i].player, _layout[i].amount * 12);
                }
            }
        }

        // save the result
        _results.push(result);

        // clear the layout
        delete _layout;

        emit Settle(result);
    }

    // @notice withdraw the token from contract
    // @param _token the token address
    // @param _amount the amount of token
    function withdraw(address _token, uint256 _amount) external {
        require(_cheques[msg.sender][_token] >= _amount, "not enough credit");
        _cheques[msg.sender][_token] -= _amount;
        _safeTransfer(_token, msg.sender, _amount);
    }

    // @notice withdraw the token from contract, only owner can call this function
    // @param _token the token address
    // @param _amount the amount of token
    function withdrawOnlyOwner(address _token, uint256 _amount) external onlyOwner {
        _safeTransfer(_token, msg.sender, _amount);
    }

    // @notice get the point of the card
    // @param _rank the rank of the card
    function _getPoint(uint8 cardId) internal pure returns (uint8) {
        uint8 rank = cardId % 13;
        // 10, J, Q, K
        if (rank == 0 || rank >= 10) {
            return 0;
        }
        return rank;
    }

    // @notice transfer the token, or record the cheque
    // if the token is address 0, it means the token is ETH
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

    // @notice check whether can be settle, only can be settle when have banker and player
    // @return true if can be settle
    function _checkAction() internal view returns (bool) {
        // need both have banker and player betting
        bool banker = false;
        bool player = false;
        for (uint256 i = 0; i < _layout.length; i++) {
            if (_layout[i].betType == uint256(BetType.Banker)) {
                banker = true;
            } else if (_layout[i].betType == uint256(BetType.Player)) {
                player = true;
            }
        }

        return banker && player;
    }

    // @notice burn some cards after init shuffle
    function _burning() internal {
        uint8 point = _getPoint(_shoe[_cursor]);
        if (point <= 7) {
            _cursor += 3;
        } else {
            _cursor += 2;
        }

        emit Burning(point);
    }

    function shuffle(uint256 _nonce) external {
        _shuffle(_nonce);
    }

    // @notice Use Knuth shuffle algorithm to shuffle the cards
    // @param _nonce random number, from business data and block data
    function _shuffle(uint256 _nonce) internal {
        _shuffle(_nonce, _shoe.length);
    }

    // @notice Use Knuth shuffle algorithm to shuffle the cards
    // @param _nonce random number, from business data and block data
    // @param _to shuffle cards between _cursor to _to, _to must <= _shoe.length
    function _shuffle(uint256 _nonce, uint256 _to) internal {
        for (uint256 i = _cursor; i < _to; i++) {
            _nonce = uint256(keccak256(abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    i,
                    _nonce
                )));
            // Pseudo random number between i and _shoe.length - 1
            uint256 j = i + _nonce % (_shoe.length - i);
            // swap i and j
            uint8 temp = _shoe[i];
            _shoe[i] = _shoe[j];
            _shoe[j] = temp;
        }
        emit Shuffle(_nonce);
        // when cursor is 0, need to burn some cards
        if (_cursor == 0) {
            _burning();
        }
    }

    // @notice get the card from the shoe
    // @return the card id
    function shoe() external view returns (uint8[] memory) {
        return _shoe;
    }

    // @notice get the actions at the current layout
    // @return the actions
    function layout() external view returns (LayoutAction[] memory) {
        return _layout;
    }

    // @notice get current cursor of shoe
    // @return the cursor
    function cursor() external view returns (uint256) {
        return _cursor;
    }

    // @notice get cheque balance of the user
    // @param _player the player address
    // @param _token the token address
    // @return the cheque balance
    function chequesOf(address _player, address _token) external view returns (uint256) {
        return _cheques[_player][_token];
    }

    // @notice get the settle results
    // @param from_ start index, from 0
    // @param count_ the number of settle results
    // @return the settle results
    function results() external view returns (Result[] memory) {
        return _results;
    }
}