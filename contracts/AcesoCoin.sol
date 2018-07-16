pragma solidity 0.4.24;

import "zeppelin-solidity/contracts/token/ERC20/CappedToken.sol";
import "zeppelin-solidity/contracts/token/ERC20/PausableToken.sol";


contract AcesoCoin is CappedToken, PausableToken {
  using SafeMath for uint256;
  string public name = "ACESO COIN";
  string public symbol = "ASO";
  uint256 public decimals = 18;
  
  constructor(uint256 cap) public
    CappedToken(cap) {
  }
}
