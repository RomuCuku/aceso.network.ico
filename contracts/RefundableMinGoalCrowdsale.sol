pragma solidity 0.4.24;


import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/crowdsale/distribution/FinalizableCrowdsale.sol";
import "zeppelin-solidity/contracts/math/Math.sol";
import "zeppelin-solidity/contracts/crowdsale/distribution/utils/RefundVault.sol";


/**
 * @title RefundableMinGoalCrowdsale
 * @dev Extension of Crowdsale contract that adds a funding goal, and
 * the possibility of users getting a refund if goal is not met.
 * Uses a RefundVault as the crowdsale's vault.
 */
contract RefundableMinGoalCrowdsale is FinalizableCrowdsale {
  using SafeMath for uint256;

  // minimum amount of funds to be raised in weis
  uint256 public tokensMinGoal;

  // refund vault used to hold funds while crowdsale is running
  RefundVault public vault;

  bool public isVaultClaimed = false;

  /**
   * @dev Constructor, creates RefundVault.
   * @param _tokensMinGoal Funding goal
   */
  constructor(uint256 _tokensMinGoal) public {
    require(_tokensMinGoal > 0);
    vault = new RefundVault(wallet);
    tokensMinGoal = _tokensMinGoal;
  }

  /**
   * @dev Investors can claim refunds here if crowdsale is unsuccessful
   */
  function claimRefund() public {
    require(isFinalized);
    require(!minGoalReached());

    vault.refund(msg.sender);
  }

  /**
   * @dev Checks whether funding min goal was reached.
   * @return Whether funding min goal was reached
   */
  function minGoalReached() public view returns (bool) {
    return token.totalSupply() >= tokensMinGoal;
  }


  /**
   * @dev Must be called after crowdsale ends, to do some extra finalization
   * work. Calls the contract's finalization function.
   */
  function claimVault() onlyOwner public {
    require(minGoalReached());
    require(!isVaultClaimed);
    vault.close();
    isVaultClaimed = true;
  }

  /**
   * @dev vault finalization task, called when owner calls finalize()
   */
  function finalization() internal {
    if (!minGoalReached()) {
      vault.enableRefunds();
    } else if (!isVaultClaimed) {
      claimVault();
    }
    super.finalization();
  }

  /**
   * @dev Overrides Crowdsale fund forwarding, sending funds to vault until min goal.
   */
  function _forwardFunds() internal {
    /* We forward funds to vault until it is claimed.
     * Note that it can be clamed only if min goal reached
     */
    if (!isVaultClaimed) {
      vault.deposit.value(msg.value)(msg.sender);
    } else {
      super._forwardFunds();
    }
  }

}
