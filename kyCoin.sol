
pragma solidity ^0.8.0;
//SPDX-License-Identifier: UNLICENSED
//0xF01349Dd52117433C7a3E1C8434948dBfff87b85

contract Authority {
    struct trusted {
        address pubKey;
        string meta;
        bool isValid;
    }
    mapping (address => trusted) public trustList;
    address public owner;
    address[] public trustAddresses;
    event Added(address pubKey, string meta);
    event Removed(address pubKey, string meta);

    constructor() {
        owner = msg.sender;
    }

    modifier isOwned() {
        require(msg.sender == owner);
        _;
    }

    function changeOwner (address newOwner) isOwned public {
        owner = newOwner;
    }

    function approveAddress(address pubKey, string memory meta) isOwned public {
        require(!trustList[pubKey].isValid);
        trustList[pubKey] = trusted(pubKey, meta, true);
        trustAddresses.push(pubKey);
        emit Added(pubKey, meta);
    }

    function revokeAddress(address pubKey) isOwned public {
        require(trustList[pubKey].isValid);
        for (uint i = 0; i < trustAddresses.length; i++) {
            if (trustAddresses[i] == pubKey) {
                trustAddresses[i] = trustAddresses[trustAddresses.length - 1];
                delete trustAddresses[trustAddresses.length - 1];
                trustAddresses.pop();
                break;
            }
        }
        trustList[pubKey].isValid = false;
        emit Removed(pubKey, trustList[pubKey].meta);
    }

    function isTrusted(address pubKey) public view returns (bool) {
        return trustList[pubKey].isValid;
    }

    function getTrustMeta(address pubKey) public view returns (string memory) {
        return trustList[pubKey].meta;
    }
}


//0x5Bd06AE354d69B3Fc40830592f7aABd98AA6286b

contract CertKYC {

    Authority public auth;
    struct validation {
        address certifier;
        bool validation;
    }
    mapping (address => validation) public KYC;
    event add (address _address, address _certifier);
    event revoke (address _address, address _certifier);

constructor (address _authority) {
auth = Authority(_authority);
}

function addKYC (address _address)  public {
    require (auth.isTrusted(msg.sender));
    KYC[_address].certifier = msg.sender;
    KYC[_address].validation = true;
    emit add (_address, msg.sender);
    }

function remID(address _address) public {
    require (auth.isTrusted(msg.sender));
    require (!KYC[_address].validation);
    KYC[_address].validation = false;
    emit revoke (_address, msg.sender);
	}

function isKYC(address pubKey) public view returns (bool) {
    return KYC[pubKey].validation;
}

}



//0x68d87E79B1bD2E57Ded909a83C5c5B24E7385206

contract owned {
    address public owner;

    constructor ()  {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}

interface tokenRecipient { function receiveApproval (address _from, uint256 _value, address _token, bytes calldata _extraData) external; }

contract TokenERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    CertKYC public _kyc;

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Burn(address indexed from, uint256 value);

    constructor (
        address kyc_,
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) {
        totalSupply = initialSupply * 10 ** uint256(decimals); 
        balanceOf[address(this)] = totalSupply;                
        name = tokenName;                                  
        symbol = tokenSymbol; 
        _kyc = CertKYC(kyc_);                         
    }

    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != address(0x0));
        require(_kyc.isKYC(_to));
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public
        returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData)
        public
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
    }

    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(msg.sender, _value);
        return true;
    }

    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);                
        require(_value <= allowance[_from][msg.sender]);    
        balanceOf[_from] -= _value;                         
        allowance[_from][msg.sender] -= _value;            
        totalSupply -= _value;                             
        emit Burn(_from, _value);
        return true;
    }
}

contract KYCoin is owned, TokenERC20 {  //nom du contrat Token a changer aussi dans le constructeur


    constructor (address kyc_) TokenERC20(kyc_, 21000000, "KYCoin", "KYC") {} //changer les parms ici

    fallback() payable external{
        uint amount = msg.value * 100;               
        _transfer(address(this), msg.sender, amount);              
    }

    function retrieve() onlyOwner public {
      if (!payable(owner).send(address(this).balance)) revert();
    }
   
}
