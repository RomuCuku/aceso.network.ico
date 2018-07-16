pragma solidity 0.4.24;

import "./ReferrableCrowdsale.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";


/**
 * @dev This contract is used for Crowdsale referrals. ReferrableCrowdsale
 * can create this Referral for a specified advertiser with a
 * specified reward bonus percent. Advertiser can advertise the ReferrableCrowdsale
 * and share this Referral address. All purchases to this Referral will be
 * forwarded to the ReferrableCrowdsale. If ReferrableCrowdsale receives ether from
 * this contract it will additionally transfer tokens to the advertiser
 * based on the reward bonus percent.
 */
contract AcesoCoinCrowdsaleReferral is Ownable {
  using SafeMath for uint256;

  ReferrableCrowdsale public crowdsale;
  uint256 public etherCollected;
  uint256 public tokensCollected;
  uint256 public rewardTokensEarned;
  uint256 public bonusPercent;
  address public advertiser;
  bool public disabled = false;

  /**
   * @dev Constructor, creates AcesoCoinCrowdsaleReferral.
   * @param _crowdsale Crowdsale to forwards wei to.
   * @param _advertiser address that receives referral bonus.
   * @param _bonusPercent percent of bonus to be payed to .
   */
  constructor(ReferrableCrowdsale _crowdsale, address _advertiser, uint256 _bonusPercent) public {
    crowdsale = _crowdsale;
    advertiser = _advertiser;
    bonusPercent = _bonusPercent;
  }

  /**
   * @dev fallback function
   */
  function () external payable {
    buyTokens(msg.sender);
  }

  /**
   * @dev Function for buying tokens from a crowdsale. It forwards wei to
   * crowdsale contract. Crowdsale contract detects that wei was sent
   * from this referral contract and pays reward tokens to advertiser
   */
  function buyTokens(address _beneficiary) public payable {
    require(_beneficiary != advertiser, "can not self pay for referral");
    require(!disabled, "This referral address has been disabled");
    crowdsale.buyTokens.value(msg.value)(_beneficiary);
    etherCollected = etherCollected.add(msg.value);
  }

  /**
   * @dev Disables the referral so that no ether deposits are possible.
   */
  function disable() onlyOwner public {
    disabled = true;
  }

  /**
   * @dev used by a crowdsale contract to callback Referral contract when the
   * tokens have been purchased. This data is stored for statistics purpose.
   */
  function tokensPurchasedCallback(uint256 _tokensCollected, uint256 _rewardTokensEarned) onlyOwner public {
    tokensCollected = tokensCollected.add(_tokensCollected);
    rewardTokensEarned = rewardTokensEarned.add(_rewardTokensEarned);
  }


}
