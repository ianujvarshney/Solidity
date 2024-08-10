// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(token.transfer(to, value), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(token.transferFrom(from, to, value), "SafeERC20: transferFrom failed");
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(token.approve(spender, value), "SafeERC20: approve failed");
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        require(token.approve(spender, newAllowance), "SafeERC20: increase allowance failed");
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
        uint256 newAllowance = oldAllowance - value;
        require(token.approve(spender, newAllowance), "SafeERC20: decrease allowance failed");
    }
}

abstract contract Proxy {
    function _delegate(address implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _implementation() internal virtual view returns (address);

    function _fallback() internal {
        _delegate(_implementation());
    }

    fallback() payable external {
        _fallback();
    }

    receive() payable external {
        _fallback();
    }
}

abstract contract Ronx is Proxy {
    address public impl;
    address public contractOwner;

    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "only contract owner can call this function");
        _;
    }

    modifier onlyImpl() {
        require(msg.sender == impl, "only implementation can call this function");
        _;
    }

    constructor(address _impl) {
        impl = _impl;
        contractOwner = msg.sender;
    }

    function update(address _impl) external onlyContractOwner {
        impl = _impl;
    }

    function removeOwnership() public onlyContractOwner {
        contractOwner = address(0);
    }

    function _implementation() internal override view returns (address) {
        return impl;
    }
}

contract RonxBasic {
    address public impl;
    address public contractOwner;

    struct User {
        uint id;
        address referrer;
        string firstName;
        string lastName;
        string email;
        bytes32 passwordHash;
        string profilePicture;
        string referralLink;
        uint partnersCount;
        mapping(uint8 => bool) activeX3Levels;
        mapping(uint8 => X3) x3Matrix;
    }

    struct X3 {
        address currentReferrer;
        address[] referrals;
        bool blocked;
        uint reinvestCount;
        mapping(uint => uint) referralsReinvestCounts; // referrals id => reinvestCount
        mapping(uint => uint) referralsBalances; // referrals id => balance
    }

    struct Transaction {
        uint amount;
        uint timestamp;
        string description;
    }

    uint8 public LAST_LEVEL;
    mapping(address => User) public users;
    mapping(uint => address) public idToAddress;
    mapping(uint => address) public userIds;
    mapping(address => uint) public balances;
    mapping(address => Transaction[]) public transactionHistory;
    uint public lastUserId;
    address public id1;
    address public multisig;
    mapping(uint8 => uint) public levelPrice;

    IERC20 public depositToken;
    uint public BASIC_PRICE;
    // 1 BUSD as the transaction fee

    bool public locked;

    event Registration(address indexed user, address indexed referrer, uint indexed userId, uint referrerId);
    event Reinvest(address indexed user, address indexed currentReferrer, address indexed caller, uint8 matrix, uint8 level);
    event Upgrade(address indexed user, address indexed referrer, uint8 matrix, uint8 level);
    event NewUserPlace(address indexed user, address indexed referrer, uint8 matrix, uint8 level, uint8 place);
    event MissedBUSDReceive(address indexed receiver, address indexed from, uint8 matrix, uint8 level);
    event SentExtraBUSDDividends(address indexed from, address indexed receiver, uint8 matrix, uint8 level);
}

contract RonxMatrix is RonxBasic {
    using SafeERC20 for IERC20;

    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "only contract owner can call this function");
        _;
    }

    modifier onlyUnlocked() {
        require(!locked || msg.sender == contractOwner);
        _;
    }

    function init(address _ownerAddress, address _multisig, IERC20 _depositTokenAddress) public onlyContractOwner {
        BASIC_PRICE = 5e18;
        LAST_LEVEL = 12;
        levelPrice[1] = BASIC_PRICE;
        for (uint8 i = 2; i <= 8; i++) {
            levelPrice[i] = levelPrice[i - 1] * 2;
        }
        levelPrice[9] = 1250e18;
        levelPrice[10] = 2500e18;
        levelPrice[11] = 5000e18;
        levelPrice[12] = 9900e18;

        id1 = _ownerAddress;
        User storage user = users[_ownerAddress];
        user.id = 1;
        user.referrer = address(0);
        user.partnersCount = 0;
        user.referralLink = generateReferralLink(_ownerAddress);
        idToAddress[1] = _ownerAddress;
        for (uint8 i = 1; i <= LAST_LEVEL; i++) {
            users[_ownerAddress].activeX3Levels[i] = true;
        }
        lastUserId = 2;
        depositToken = _depositTokenAddress;
        multisig = _multisig;
        locked = true;
    }

    function changeLock() external onlyContractOwner {
        locked = !locked;
    }

    fallback() external {
        if (msg.data.length == 0) {
            return registration(msg.sender, id1, "", "", "", "", "");
        }

        registration(msg.sender, bytesToAddress(msg.data), "", "", "", "", "");
    }

    function registrationExt(
        address referrerAddress,
        string memory firstName,
        string memory lastName,
        string memory email,
        string memory password,
        string memory profilePicture
    ) external onlyUnlocked {
        registration(msg.sender, referrerAddress, firstName, lastName, email, password, profilePicture);
    }

    function registrationFor(
        address userAddress,
        address referrerAddress,
        string memory firstName,
        string memory lastName,
        string memory email,
        string memory password,
        string memory profilePicture
    ) external onlyUnlocked {
        registration(userAddress, referrerAddress, firstName, lastName, email, password, profilePicture);
    }

    function buyNewLevel(uint8 matrix, uint8 level) external onlyUnlocked {
        _buyNewLevel(msg.sender, matrix, level);
    }

    function buyNewLevelFor(address userAddress, uint8 matrix, uint8 level) external onlyUnlocked {
        _buyNewLevel(userAddress, matrix, level);
    }

    function _buyNewLevel(address _userAddress, uint8 matrix, uint8 level) internal {
        require(isUserExists(_userAddress), "user is not exists. Register first.");
        require(matrix == 1 || matrix == 2, "invalid matrix");

        depositToken.safeTransferFrom(msg.sender, address(this), levelPrice[level]);
        require(level > 1 && level <= LAST_LEVEL, "invalid level");

        if (matrix == 1) {
            require(users[_userAddress].activeX3Levels[level - 1], "buy previous level first");
            require(!users[_userAddress].activeX3Levels[level], "level already activated");

            if (users[_userAddress].x3Matrix[level - 1].blocked) {
                users[_userAddress].x3Matrix[level - 1].blocked = false;
            }

            address freeX3Referrer = findFreeX3Referrer(_userAddress, level);
            users[_userAddress].x3Matrix[level].currentReferrer = freeX3Referrer;
            users[_userAddress].activeX3Levels[level] = true;
            updateX3Referrer(_userAddress, freeX3Referrer, level);

            emit Upgrade(_userAddress, freeX3Referrer, 1, level);
        } else {
            revert("Invalid matrix value");
        }
    }

    function registration(
        address userAddress,
        address referrerAddress,
        string memory firstName,
        string memory lastName,
        string memory email,
        string memory password,
        string memory profilePicture
    ) private {
        require(!isUserExists(userAddress), "user exists");
        require(isUserExists(referrerAddress), "referrer not exists");
        require(msg.value == BASIC_PRICE, "invalid registration cost");
    }
        users[userAddress] = User({
            id: lastUserId,
            referrer: referrerAddress,
            firstName: firstName,
            lastName: lastName,
            email: email,
            passwordHash: keccak256(abi.encodePacked(password)),
            profilePicture: profilePicture,
            referralLink: generateReferralLink(userAddress),
            partnersCount: 0
        });

        idToAddress[lastUserId] = userAddress;
        users[userAddress].referrer = referrerAddress;
        users[userAddress].activeX3Levels[1] = true;

        lastUserId++;

        users[referrerAddress].partnersCount++;

        address freeX3Referrer = findFreeX3Referrer(userAddress, 1);
        users[userAddress].x3Matrix[1].currentReferrer = freeX3Referrer;
        updateX3Referrer(userAddress, freeX3Referrer, 1);

        emit Registration(userAddress, referrerAddress, users[userAddress].id, users[referrerAddress].id);
    }

    function updateX3Referrer(address userAddress, address referrerAddress, uint8 level) private {
        users[referrerAddress].x3Matrix[level].referrals.push(userAddress);

        if (users[referrerAddress].x3Matrix[level].referrals.length < 3) {
            emit NewUserPlace(userAddress, referrerAddress, 1, level, uint8(users[referrerAddress].x3Matrix[level].referrals.length));
            return sendBUSDDividends(referrerAddress, userAddress, 1, level);
        }

        emit NewUserPlace(userAddress, referrerAddress, 1, level, 3);
        users[referrerAddress].x3Matrix[level].referrals = new address[](0);

        if (!users[referrerAddress].activeX3Levels[level + 1] && level != LAST_LEVEL) {
            users[referrerAddress].x3Matrix[level].blocked = true;
        }

        if (referrerAddress != id1) {
            address freeReferrerAddress = findFreeX3Referrer(referrerAddress, level);
            if (users[referrerAddress].x3Matrix[level].currentReferrer != freeReferrerAddress) {
                users[referrerAddress].x3Matrix[level].currentReferrer = freeReferrerAddress;
            }

            users[referrerAddress].x3Matrix[level].reinvestCount++;
            emit Reinvest(referrerAddress, freeReferrerAddress, userAddress, 1, level);
            updateX3Referrer(referrerAddress, freeReferrerAddress, level);
        } else {
            sendBUSDDividends(id1, userAddress, 1, level);
            users[id1].x3Matrix[level].reinvestCount++;
            emit Reinvest(id1, address(0), userAddress, 1, level);
        }
    }

    function findFreeX3Referrer(address userAddress, uint8 level) public view returns (address) {
        while (true) {
            if (users[users[userAddress].referrer].activeX3Levels[level]) {
                return users[userAddress].referrer;
            }

            userAddress = users[userAddress].referrer;
        }
    }

    function usersActiveX3Levels(address userAddress, uint8 level) public view returns (bool) {
        return users[userAddress].activeX3Levels[level];
    }

    function usersX3Matrix(address userAddress, uint8 level) public view returns (address, address[] memory, bool, uint, uint[] memory) {
        return (
            users[userAddress].x3Matrix[level].currentReferrer,
            users[userAddress].x3Matrix[level].referrals,
            users[userAddress].x3Matrix[level].blocked,
            users[userAddress].x3Matrix[level].reinvestCount,
            users[userAddress].x3Matrix[level].referralsBalances
        );
    }

    function sendBUSDDividends(address userAddress, address _from, uint8 matrix, uint8 level) private {
        address(uint160(userAddress)).transfer(levelPrice[level]);

        if (matrix == 1) {
            users[userAddress].x3Matrix[level].referralsBalances[_from] += levelPrice[level];
        }

        emit MissedBUSDReceive(userAddress, _from, matrix, level);
    }

    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }

    function isUserExists(address userAddress) public view returns (bool) {
        return (users[userAddress].id != 0);
    }

    function generateReferralLink(address userAddress) internal pure returns (string memory) {
        bytes32 hash = keccak256(abi.encodePacked(userAddress));
        return string(abi.encodePacked("https://ronx.io/ref/", toHexString(uint160(userAddress)), "?c=", toHexString(uint256(hash))));
    }

    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = bytes1(uint8(87 + value % 16));
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}
