pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract CryptofieldBase {
    using SafeMath for uint256;

    uint256 private saleId;

    bytes32 private gender = "F"; // First horse is a male.

    /*
    @dev horseHash stores basic horse information in a hash returned by IPFS.
    */
    struct Horse {
        address buyer;

        uint256 baseValue;

        uint256 saleId;
        uint256 timestamp;
        uint256 dateSold;
        uint256 amountOfTimesSold;

        uint256[7] characteristics;

        string horseHash;
        string name;

        bytes32 sex;
    }

    mapping(uint256 => Horse) public horses;

    event HorseSell(uint256 _horseId, uint256 _amountOfTimesSold);
    event HorseBuy(address _buyer, uint256 _timestamp, uint256 _saleId);

    // Called internally, i.e. when not creating offsprings.
    function buyHorse(address _buyer, string _horseHash, uint256 _tokenId) internal {
        saleId = saleId.add(1);

        bytes32[2] memory gen = [bytes32("M"), bytes32("F")];

        if(gender == gen[0]) {gender = gen[1];} else {gender = gen[0];}

        Horse memory horse;
        horse.buyer = _buyer;
        horse.saleId = saleId;
        // The use of 'now' here shouldn't be a concern since that's only used for the timestamp of a horse
        // which really doesn't have much effect on the horse itself.
        horse.timestamp = now;
        horse.horseHash = _horseHash;
        horse.sex = gender;
        horse.baseValue = _getRand();

        horses[_tokenId] = horse;

        emit HorseBuy(_buyer, now, horse.saleId);
    }

    // This function is called when the call isn't coming from an offspring.

    /*
    @dev Only returns the hash containing basic information of horse (name, color, origin, etc...)
    @param _horseId Token of the ID to retrieve hash from.
    @returns string, IPFS hash
    */

    function getHorse(uint256 _horseId) public view returns(string) {
        return horses[_horseId].horseHash;
    }

    /*
    @dev Returns sex of horse.
    */
    function getHorseSex(uint256 _horseId) public view returns(bytes32) {
        return horses[_horseId].sex;
    }

    /*
    @dev Gets the base value of a given horse.
    */
    function getBaseValue(uint256 _horseId) public view returns(uint) {
        return horses[_horseId].baseValue;
    }

    /*
    @dev Adds 1 to the amount of times a horse has been sold.
    @dev Adds unix timestamp of the date the horse was sold.
    */

    //TODO: Add modifier in this function
    function horseSold(uint256 _horseId) internal {
        Horse storage horse = horses[_horseId];
        horse.amountOfTimesSold = horse.amountOfTimesSold.add(1);
        horse.dateSold = now;

        emit HorseSell(_horseId, horse.amountOfTimesSold);
    }

    function getTimestamp(uint256 _horseId) public view returns(uint256) {
        return horses[_horseId].timestamp;
    }

    /*
    @dev Gets the name of a given horse
    */
    function getHorseName(uint256 _horseId) public view returns(string) {
        return horses[_horseId].name;
    }

    /* RESTRICTED FUNCTIONS /*

    /*
    @dev Changes the baseValue of a horse, this is useful when creating offspring and should be
    allowed only by the breeding contract.
    */

    // TODO: Add Breeding contract modifier
    function setBaseValue(uint256 _horseId, uint256 _baseValue) external {
        Horse storage h = horses[_horseId];
        h.baseValue = _baseValue;
    }

    function setNameFor(string _name, uint256 _horseId) internal {
        horses[_horseId].name = _getName(_name, _horseId);
    }

    /* PRIVATE FUNCTIONS */

    /*
    @dev Gets a random number between 1 and 'max';
    */
    function _getRand(uint256 _max) private view returns(uint256) {
        return uint256(blockhash(block.number.sub(1))) % _max + 1;
    }

    /*
    @dev Gets random number between 1 and 50.
    */
    function _getRand() private view returns(uint256) {
        return uint256(blockhash(block.number.sub(1))) % 50 + 1;
    }

    /*
    @dev Generates a random name depending on the input
    */
    function _getName(string _name, uint256 _Id) private pure returns(string) {
        if(keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked(""))) {
            // Generate a random name.
            return strConcat("X", uint2str(_Id));
        }

        return _name;
    }

    /* ORACLIZE IMPLEMENTATION */

    /* @dev Converts 'uint' to 'string' */
    function uint2str(uint256 i) internal pure returns(string) {
        if (i == 0) return "0";
        uint256 j = i;
        uint256 len;
        while (j != 0){
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        while (i != 0){
            bstr[k--] = byte(48 + i % 10);
            i /= 10;
        }
        return string(bstr);
    }

    /* @dev Concatenates two strings together */
    function strConcat(string _a, string _b, string _c, string _d, string _e) internal pure returns (string) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
        for (i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
        for (i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
        for (i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
        for (i = 0; i < _be.length; i++) babcde[k++] = _be[i];
        return string(babcde);
    }

    function strConcat(string _a, string _b, string _c, string _d) internal pure returns (string) {
        return strConcat(_a, _b, _c, _d, "");
    }

    function strConcat(string _a, string _b, string _c) internal pure returns (string) {
        return strConcat(_a, _b, _c, "", "");
    }

    function strConcat(string _a, string _b) internal pure returns (string) {
        return strConcat(_a, _b, "", "", "");
    }
}
