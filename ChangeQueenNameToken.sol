pragma solidity ^0.7.0;

import "../utils/IERC165.sol";
import "../utils/SafeMath.sol";
import "../utils/IERC20.sol";
import "../utils/IQueens.sol";
import "../utils/Context.sol";

/**
 *
 * ChangeQueenNameToken (A utility Token to change your Queen's name)
 * @dev Extends standard ERC20 contract
 */
contract ChangeQueenNameToken is Context, IERC20 {
    using SafeMath for uint256;

    // Constants
    uint256 public SECONDS_IN_A_DAY = 86400;

    // PRICE OF ONE TIME CHANGING OF NAME
    uint256 public constant INITIAL_ALLOTMENT = 915 * (10 ** 18);

    uint256 public constant BONUS_FACTOR = 2;

    // Public variables
   

    // 10 TOKEN A DAY, 10** 18 IS IN WEI
    uint256 public coinDropPerDay = 10 * (10 ** 18);

    uint256 public coinDropStart;

    uint256 public coinDropEnd; 

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;
    
    mapping(uint256 => uint256) private _lastClaim;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    address private _bitQueenAddress;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18. Also initalizes {coinDropStart}
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol, uint256 coinDropStartTimestamp) {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
        
        coinDropStart = coinDropStartTimestamp;
        
        //AFTER 10 YEARS EMISSION STOPS
        coinDropEnd = coinDropStartTimestamp + (86400 * 365 * 10);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev Returns TimeStamp when the CQNT was last claimed for tokenID
     */
    function getLastClaimedTimeStamp(uint256 tokenIndex) public view returns (uint256) {
        require(IQueens(_bitQueenAddress).ownerOf(tokenIndex) != address(0), "Owner cannot be 0 address");
        require(tokenIndex < IQueens(_bitQueenAddress).totalSupply(), "NFT at index has not been minted yet");

        uint256 lastClaimed = uint256(_lastClaim[tokenIndex]) != 0 ? uint256(_lastClaim[tokenIndex]) : coinDropStart;
        return lastClaimed;
    }
    
    /**
     * @dev Returns the accumulated CQNT tokens gathered by holding BitQueens
     */
    function getAccumulatedQty(uint256 tokenIndex) public view returns (uint256) {
        require(block.timestamp > coinDropStart, "Coin Drop not started yet");
        require(IQueens(_bitQueenAddress).ownerOf(tokenIndex) != address(0), "Owner cannot be 0 address");
        require(tokenIndex < IQueens(_bitQueenAddress).totalSupply(), "NFT at index has not been minted yet");

        uint256 lastClaimedTime = getLastClaimedTimeStamp(tokenIndex);

        // Sanity check if last claim was on or after emission end
        if (lastClaimedTime >= coinDropEnd) return 0;

        uint256 accumulationPeriod = block.timestamp < coinDropEnd ? block.timestamp : coinDropEnd; // Getting the min value of both
        uint256 totalAccumulated = accumulationPeriod.sub(lastClaimedTime).mul(coinDropPerDay).div(SECONDS_IN_A_DAY);

        // If claim hasn't been done before for the index, add initial allotment (plus prereveal multiplier if applicable)
        if (lastClaimedTime == coinDropStart) {
            uint256 initialAllotment = IQueens(_bitQueenAddress).isMintedBeforeReveal(tokenIndex) == true ? INITIAL_ALLOTMENT.mul(BONUS_FACTOR) : INITIAL_ALLOTMENT;
            totalAccumulated = totalAccumulated.add(initialAllotment);
        }

        return totalAccumulated;
    }

    /**
     * @dev Only set once and needed to called immediately after contract deployment.
     */
    function setBitQueenAddress(address bitQueenAddress) public {
        require(_bitQueenAddress == address(0), "Already set");
        
        _bitQueenAddress = bitQueenAddress;
    }
    
    /**
     * @dev Function gets the acccumulated CQNT tokens of all tokenIndices and mints them if more than zero.
     */
    function claim(uint256[] memory tokenIndices) public returns (uint256) {
        require(block.timestamp > coinDropStart, "Coin Drop not started yet");

        uint256 totalCqntClaimable = 0;
        for (uint index = 0; index < tokenIndices.length; index++) {
            // Sanity check for non-minted index
            require(tokenIndices[index] < IQueens(_bitQueenAddress).totalSupply(), "NFT at index has not been minted yet");
            // Duplicate token index check
            for (uint checkIndex = index + 1; checkIndex < tokenIndices.length; checkIndex++) {
                require(tokenIndices[index] != tokenIndices[checkIndex], "TokenIndex is repeated");
            }

            uint tokenIndex = tokenIndices[index];
            require(IQueens(_bitQueenAddress).ownerOf(tokenIndex) == msg.sender, "Sender is not the owner");

            uint256 claimQty = getAccumulatedQty(tokenIndex);
            if (claimQty != 0) {
                totalCqntClaimable = totalCqntClaimable.add(claimQty);
                _lastClaim[tokenIndex] = block.timestamp;
            }
        }

        require(totalCqntClaimable != 0, "Accumulated CQNT balance is 0");
        _mint(msg.sender, totalCqntClaimable);

        return totalCqntClaimable;
    }


    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        // Approval check is skipped just for easiness if the caller of transferFrom is the BitQueens contract
        if (msg.sender != _bitQueenAddress) {
            _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        }
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    // ++
    /**
     * @dev Burns a quantity of tokens held by the caller.
     *
     * Emits an {Transfer} event to 0 address
     *
     */
    function burn(uint256 burnQuantity) public virtual override returns (bool) {
        _burn(msg.sender, burnQuantity);
        return true;
    }
    // ++

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}