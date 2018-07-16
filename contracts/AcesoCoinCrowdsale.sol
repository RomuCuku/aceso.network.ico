pragma solidity 0.4.24;

import "./RefundableMinGoalCrowdsale.sol";
import "./AcesoCoinCrowdsaleReferral.sol";
import "./ReferrableCrowdsale.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "zeppelin-solidity/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "zeppelin-solidity/contracts/token/ERC20/CappedToken.sol";
import "zeppelin-solidity/contracts/token/ERC20/PausableToken.sol";
import "zeppelin-solidity/contracts/token/ERC20/TokenTimelock.sol";


/**
 * @title AcesoCoinCrowdsale
 * @dev Crowdsale for Aceso Coin.
 * This crowdsale can mint tokes directly to investors. This is typically done during preICO stage. Also this could be done if investors want to buy tokens using FIAT currencies.
 * This crowdsale has dynamic stages for public token purchase. Tokens can only be purchased if a stage has been started.
 * This is a TimedCrowdsale meaning that it has a start and end time.
 * This is a CappedCrowdsale meaning that amount of tokens to be sold can not be more that a specified cap.
 * This is a ReferrableContract meaning that Referrals could be created for this contract for advertisers who get bonus if tokens are bought using their referral address.
 * This is a RefundableMinGoalCrowdsale meaning that if min goal is not reached then investors can claim back invested funds after crowdsale close time.
 * This is a FinalizableCrowdsale meaning that after crowdsale ends additional finalization steps are done. See finalization() function.
 */
contract AcesoCoinCrowdsale is TimedCrowdsale, RefundableMinGoalCrowdsale, ReferrableCrowdsale, CappedCrowdsale {
  using SafeMath for uint256;

  uint256 public hardCap;
  uint256 internal initialRate;

  uint256 public weiRemainingForCurrentStage;
  uint256 public stageOpeningTime;
  uint256 public stageClosingTime;

  event TokenTimelockCreated(address beneficiary, address timelockAddress);
  event StageStarted(
    uint256 _stageOpeningTime,
    uint256 _stageClosingTime,
    uint256 _rate,
    uint256 _limitWei
  );
  event StageStopped();

  /**
   * @dev Constructor, creates AcesoCoinCrowdsale.
   * @param _openingTime Crowdsale opening time.
   * @param _closingTime Crowdsale closing time.
   * @param _softCap Crowdsale softcap in tokens. If crowdsale ends and _softCap
   * is not reached then ether can be claimed back by investors using claimRefund.
   * @param _wallet wallet where all the raised way if forwarded to. Note that wei is only
   * transferred to wallet if softCap has been reached. Otherwise it is stored in RefundVault.
   * @param _initialRate initial token sell rate. Note that this can be changed when
   * starting a stage.
   * @param _token Token that is to be sold by this crowdsale.
   */
  constructor(
          uint256 _openingTime,
          uint256 _closingTime,
          uint256 _softCap,
          address _wallet,
          uint256 _initialRate,
          CappedToken _token
      ) public
      Crowdsale(_initialRate, _wallet, _token)
      TimedCrowdsale(_openingTime, _closingTime)
      CappedCrowdsale(_token.cap())
      RefundableMinGoalCrowdsale(_softCap) {
    require(PausableToken(_token).paused(), "You can start crowdsale on paused token only");
    hardCap = _token.cap();
    initialRate = _initialRate;
  }

  /**
   * @dev mints tokens to timelock contract which loks tokens until _releaseTime.
   * TokenTimelockCreated is fired when the timelock is created.
   * @param _to Destination address where tokens should be minted to.
   * @param _tokenAmount Token amount to be minted.
   * @param _releaseTime Time until tokes are locked in a TimeLock.
   */
  function mintTokensToTimelock(
    address _to,
    uint256 _tokenAmount,
    uint256 _releaseTime)
      onlyOwner
      public
    {
    TokenTimelock timelock = new TokenTimelock(token, _to, _releaseTime);
    mintTokens(address(timelock), _tokenAmount);
    emit TokenTimelockCreated(_to, address(timelock));
  }

  /**
   * @dev mints tokens to a destination address.
   * @param _to Destination address where tokens should be minted to.
   * @param _amount Token amount to be minted.
   */
  function mintTokens(address _to, uint256 _amount) onlyOwner public {
    require(!hasClosed(), "Crowdsale has closed");
    require(MintableToken(token).mint(_to, _amount), "Minting failed");
  }

  /**
   * @dev Starts a public crowdsale stage allowing to buy tokens by sending
   * Ether to this contract with the specivied rate. Contract will deliver
   * tokens based on this formula: tokensSent = rate * etherReceived.
   * @param _stageOpeningTime Time when the stage opens and starts receiving ether.
   * @param _stageClosingTime Time when the stage closes.
   * @param _rate Token sell rate. tokensSent = rate * etherReceived.
   * @param _limitWei Stage limit in wei. Once this amount of wei is raised active stage will be closed.
   */
  function startStage(
    uint256 _stageOpeningTime,
    uint256 _stageClosingTime,
    uint256 _rate,
    uint256 _limitWei)
      onlyOwner
      public
    {
    require(_limitWei.mul(_rate) <= remainingTokens(), "Not enough tokens to start stage");
    require(_stageOpeningTime >= openingTime, "Stage opening time can not be before crowdsale closing time");
    require(_stageClosingTime <= closingTime, "Stage closing time can not be after crowdsale closing time");
    require(_stageOpeningTime < _stageClosingTime, "Stage opening time should be before closing time");
    rate = _rate;
    weiRemainingForCurrentStage = _limitWei;
    stageOpeningTime = _stageOpeningTime;
    stageClosingTime = _stageClosingTime;
    emit StageStarted(
      _stageOpeningTime,
      _stageClosingTime,
      _rate,
      _limitWei
    );
  }

  /**
   * @dev Stops current stage before stageClosingTime.
   */
  function stopStage() onlyOwner public {
    rate = initialRate;
    weiRemainingForCurrentStage = 0;
    emit StageStopped();
  }

  /**
   * @return The total remainig tokes for the crowdsale.
   */
  function remainingTokens() public view returns (uint256) {
    return cap - token.totalSupply();
  }

  /**
   * @dev Overriding renounceOwnership and disabling it because it is not allowrd for this crowdsale
   */
  function renounceOwnership() public onlyOwner {
    revert();
  }

  /**
   * @dev Overriding transferOwnership and disabling it because it is not allowrd for this crowdsale
   */
  function transferOwnership(address _newOwner) public onlyOwner {
    revert();
  }

  /**
   * @dev Overrides Crowdsale _preValidatePurchase function. Adds additional
   * checks for stage limits.
   * @param _beneficiary Token purchaser
   * @param _weiAmount Amount of wei contributed
   */
  function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
    require(weiRemainingForCurrentStage >= _weiAmount, "Stage wei limit exceeded");
    require(block.timestamp >= stageOpeningTime && block.timestamp <= stageClosingTime, "Stage is not active");
    super._preValidatePurchase(_beneficiary, _weiAmount);
  }

  /**
  * @dev Overrides Crowdsale delivery by minting tokens upon purchase.
  * @param _beneficiary Token purchaser
  * @param _tokenAmount Number of tokens to be minted
  */
  function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
    require(MintableToken(token).mint(_beneficiary, _tokenAmount));
  }

  /**
   * @dev Overrides Crowdsale _updatePurchasingState to update weiRemainingForCurrentStage
   * @param _beneficiary Address receiving the tokens
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _updatePurchasingState(address _beneficiary, uint256 _weiAmount) internal {
    super._updatePurchasingState(_beneficiary, _weiAmount);
    weiRemainingForCurrentStage = weiRemainingForCurrentStage.sub(_weiAmount);
  }

  /**
   * @dev contract finalization task, called when owner calls finalize()
   */
  function finalization() internal {
    super.finalization();
    PausableToken(token).unpause();
    Ownable(token).transferOwnership(wallet);
  }
}
