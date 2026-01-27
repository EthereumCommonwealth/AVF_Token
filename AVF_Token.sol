pragma solidity >=0.8.2;

abstract contract IERC223Recipient {


 struct ERC223TransferInfo
    {
        address token_contract;
        address sender;
        uint256 value;
        bytes   data;
    }
    
    ERC223TransferInfo private tkn;
    
/**
 * @dev Standard ERC223 function that will handle incoming token transfers.
 *
 * @param _from  Token sender address.
 * @param _value Amount of tokens.
 * @param _data  Transaction metadata.
 */
    function tokenReceived(address _from, uint _value, bytes memory _data) public virtual returns (bytes4)
    {
        /**
         * @dev Note that inside of the token transaction handler the actual sender of token transfer is accessible via the tkn.sender variable
         * (analogue of msg.sender for Ether transfers)
         * 
         * tkn.value - is the amount of transferred tokens
         * tkn.data  - is the "metadata" of token transfer
         * tkn.token_contract is most likely equal to msg.sender because the token contract typically invokes this function
        */
        tkn.token_contract = msg.sender;
        tkn.sender         = _from;
        tkn.value          = _value;
        tkn.data           = _data;
        
        // ACTUAL CODE

        return 0x8943ec02;
    }
}

library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * This test is non-exhaustive, and there may be false-negatives: during the
     * execution of a contract's constructor, its address will be reported as
     * not containing a contract.
     *
     * > It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

/**
 * @title Reference implementation of the AVF token compatible with ERC-223.
 */
contract AVF_Token {

     /**
     * @dev Event that is fired on successful transfer.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TransferData(bytes);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event NewOwnerPending(address indexed owner);
    event NewOwner(address indexed owner);

    string  private _name;
    string  private _symbol;
    uint8   private _decimals;
    uint256 private _totalSupply;
    uint256 public  max_cap;
    address public  owner = msg.sender;
    address public  pending_owner;
    address public  DAO_Treasury;
    mapping(address account => mapping(address spender => uint256)) private allowances;
    
    mapping(address => uint256) private balances; // List of user balances.

    modifier onlyOwner
    {
        require(msg.sender == owner, "Owner error");
        _;
    }
     
    constructor()
    {
        _name     = "AVF token";
        _symbol   = "AVF";
        _decimals = 18;
        max_cap   = 8000000000 * (10 ** _decimals);
        balances[msg.sender] = 28000000 * (10 ** _decimals);
    }
    
    function name() public view returns (string memory)
    {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory)
    {
        return _symbol;
    }

    function decimals() public view returns (uint8)
    {
        return _decimals;
    }
    
    function totalSupply() public view returns (uint256)
    {
        return _totalSupply;
    }
    
    function standard() public pure returns (uint32)
    {
        return 223;
    }
    
    function balanceOf(address _owner) public view returns (uint256)
    {
        return balances[_owner];
    }
    
    function transfer(address _to, uint _value, bytes calldata _data) public payable returns (bool success)
    {
        // Standard function transfer similar to ERC20 transfer with no _data .
        // Added due to backwards compatibility reasons.
        if(msg.value > 0) payable(_to).transfer(msg.value);
        balances[msg.sender] = balances[msg.sender] - _value;
        balances[_to] = balances[_to] + _value;
        if(Address.isContract(_to)) {
            IERC223Recipient(_to).tokenReceived(msg.sender, _value, _data);
        }
        emit Transfer(msg.sender, _to, _value);
        emit TransferData(_data);
        return true;
    }
    
    function transfer(address _to, uint _value) public payable returns (bool success)
    {
        if(msg.value > 0) payable(_to).transfer(msg.value);
        bytes memory _empty = hex"00000000";
        balances[msg.sender] = balances[msg.sender] - _value;
        balances[_to] = balances[_to] + _value;
        if(Address.isContract(_to)) {
            IERC223Recipient(_to).tokenReceived(msg.sender, _value, _empty);
        }
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // ____________________________ Owner-specific functions. ____________________________________________//

    function mint(address _receiver, uint256 _quantity) public onlyOwner
    {
        require(_totalSupply + _quantity <= max_cap, "Error: minting exceeds the max token cap.");
        balances[_receiver] += _quantity;
        _totalSupply += _quantity;
        emit Transfer(address(0), _receiver, _quantity);
    }

    function burn(address _burn, uint256 _quantity) public onlyOwner
    {
        balances[_burn] -= _quantity;
        _totalSupply -= _quantity;
        emit Transfer(_burn, address(0), _quantity);
    }


    function set_DAO_Treasury(address _new_Treasury) public onlyOwner
    {
        DAO_Treasury = _new_Treasury;
    }


    // ____________________________ ERC-20 functions for backwards compatibility. ________________________//

    // Security warning!

    // ERC-20 transferFrom function does not invoke a `tokenReceived` function in the
    // recipient smart-contract. Therefore error handling is not possible
    // and a user can directly deposit tokens to any contract bypassing safety checks
    // or token reception handlers which can result in a loss of funds.
    // This functions are only supported for backwards compatibility reasons
    // and as a last resort when it may be necessary to forcefully transfer tokens
    // to some smart-contract which is not explicitly compatible with the ERC-223 standard.
    //
    // This is not a default method of depsoiting tokens to smart-contracts.
    // `trasnfer` function must be used to deposit tokens to smart-contracts
    // if the recipient supports ERC-223 depositing pattern.
    //
    // `approve` & `transferFrom` pattern must be avoided whenever possible.

    function allowance(address _owner, address spender) public view virtual returns (uint256) {
        return allowances[_owner][spender];
    }

    function approve(address _spender, uint _value) public returns (bool) {

        // Safety checks.
        require(_spender != address(0), "ERC-223: Spender error.");

        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        
        return true;
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool) {
        
        require(allowances[_from][msg.sender] >= _value, "ERC-223: Insufficient allowance.");
        
        balances[_from] -= _value;
        allowances[_from][msg.sender] -= _value;
        balances[_to] += _value;
        
        emit Transfer(_from, _to, _value);
        
        return true;
    }

    function rescueERC20(address _token, uint256 _value) external onlyOwner
    {
        (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(0xa9059cbb, msg.sender, _value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    function newOwner(address _owner) external onlyOwner
    {
        //require(msg.sender == owner);
        pending_owner = _owner;
        emit NewOwnerPending(_owner);
    }

    function claimOwnership() external
    {
        require(msg.sender == pending_owner);
        owner = pending_owner;
        emit NewOwner(msg.sender);
    }
}
