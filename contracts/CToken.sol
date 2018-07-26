pragma solidity ^0.4.2;

import "./ERC721Token.sol";
import "./CryptofieldBase.sol";

contract CToken is ERC721Token {
    uint256 stallionsAvailable = 168;
    uint256 maresAvailable = 379;
    uint256 coltsAvailable = 230;
    uint256 filliesAvailable =  334;

    // Variable for enumeration.
    address[] addresses;
    address cryptofieldBase;

    constructor(address _cryptofieldBase) ERC721Token("CToken", "CT") public {
        cryptofieldBase = _cryptofieldBase;
    }

    /* @dev Returns an array of ids of horses owned by '_from' */
    function getOwnedTokens(address _from) public view returns(uint256[]) {
        return super.getOwnedTokens(_from);
    }

    function createHorse(address _owner, string _hash) public payable {
        require(stallionsAvailable > 0);

        uint256 tokenId = addresses.push(_owner) - 1;

        _mint(_owner, tokenId);
        CryptofieldBase(cryptofieldBase).buyHorse(_owner, _hash);

        stallionsAvailable -= 1;
    }

    function transferTokenTo(address _from, address _to, uint256 _tokenId) public {
        approve(_to, _tokenId);
        safeTransferFrom(_from, _to, _tokenId);
    }

    function ownerOfToken(uint256 _tokenId) public view returns(address) {
        return ownerOf(_tokenId);
    }

    /*
    @dev Transfer a token of '_from' to '_to'
    */
    function tokenSold(address _from, address _to, uint256 _tokenId) public {
        approve(_to, _tokenId);
        safeTransferFrom(_from, _to, _tokenId);
        CryptofieldBase(cryptofieldBase).horseSold(_tokenId);
    }
}
