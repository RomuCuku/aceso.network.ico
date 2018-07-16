pragma solidity 0.4.24;

import "./AcesoCoinCrowdsaleReferral.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/crowdsale/Crowdsale.sol";
import "zeppelin-solidity/contracts/token/ERC20/CappedToken.sol";


/**
 * @title ReferrableCrowdsale
 * @dev Crowdsale capable of creating referral addresses. Referral address could
 * be used to advertise the crowdsale and get bonus if for it. If ether is transferred
 * to Referral address it is the forwarded to ReferrableCrowdsale. ReferrableCrowdsale
 * then transfers tokes to advertiser based on the bonus percent.
 */
contract ReferrableCrowdsale is Crowdsale, Ownable {
  using SafeMath for uint256;

  mapping (address => address) public addressToReferral;
  mapping (address => address) public referralToAddress;

  event ReferralRewarded(address advertiser, uint256 tokens);
  event ReferralCreated(address advertiser, address referralAddress);
  event ReferralRemoved(address advertiser, address referralAddress);

  /**
   * @dev Creates referral address
   * @param _advertiser Advertiser address. This address will receive tokes as a bonus
   * if tokens are bought using a created referral address.
   * @param _bonusPercent Token bonus percent to be transfered to advertiser.
   */
  function createReferral(address _advertiser, uint256 _bonusPercent) onlyOwner public {
    require(addressToReferral[_advertiser] == address(0x0), "Referral already created");
    AcesoCoinCrowdsaleReferral referral = new AcesoCoinCrowdsaleReferral(this, _advertiser, _bonusPercent);
    addressToReferral[_advertiser] = address(referral);
    referralToAddress[address(referral)] = _advertiser;
    emit ReferralCreated(_advertiser, address(referral));
  }

  /**
   * @dev Removes and disables an existing referral.
   * @param _advertiser Advertiser address for which the referral should be removed.
   */
  function removeReferral(address _advertiser) onlyOwner public {
    require(addressToReferral[_advertiser] != address(0x0), "Referral does not exist");
    address referralContractAddress = addressToReferral[_advertiser];
    delete addressToReferral[_advertiser];
    delete referralToAddress[referralContractAddress];
    AcesoCoinCrowdsaleReferral(referralContractAddress).disable();
    emit ReferralRemoved(_advertiser, referralContractAddress);
  }

  /**
   * @dev Removes and disables an existing referral.
   * @param _referralAddress Referral address to be removed.
   */
  function removeReferralByRefAddress(address _referralAddress) onlyOwner public {
    removeReferral(getReferralAddressAdvertiser(_referralAddress));
  }

  /**
   * @param _advertiser Advertiser address to be checked.
   * @return Currently active referral address for the specified _advertiser
   */
  function getReferralAddress(address _advertiser) public view returns (address) {
    return addressToReferral[_advertiser];
  }

  /**
   * @param _referralAddress Referral address to be checked
   * @return Advertiser address for provided _referralAddress
   */
  function getReferralAddressAdvertiser(address _referralAddress) public view returns (address) {
    return referralToAddress[_referralAddress];
  }

  /**
   * @dev checks if this is a valid referral address which was created by this crowdsale
   * @param _referralAddress Referral address to be checked
   * @return true if this address is a referral address created by this crowdsale
   */
  function isValidReferalAddress(address _referralAddress) public view returns (bool) {
    return referralToAddress[_referralAddress] != address(0x0);
  }

  /**
   * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
   * @param _beneficiary Address receiving the tokens
   * @param _tokenAmount Number of tokens to be purchased
   */
  function _processPurchase(
    address _beneficiary,
    uint256 _tokenAmount
  )
    internal
  {
    super._processPurchase(_beneficiary, _tokenAmount);
    _calculateAndDeliverReferralBonus(_tokenAmount);
  }

  /**
   * @dev Delivers referral bonus tokens to advertiser.
   * @param _tokenAmountDeliveredDuringPurchase Amount that was payed to the _beneficiary
   * durint token purchase. This amount is used to calculate how much tokens should be
   * delivered to the advertiser.
   */
  function _calculateAndDeliverReferralBonus(uint256 _tokenAmountDeliveredDuringPurchase) internal {
    address referralOwner = referralToAddress[msg.sender];
    if (referralOwner != address(0x0)) {
      AcesoCoinCrowdsaleReferral referral = AcesoCoinCrowdsaleReferral(msg.sender);
      uint256 bonusPercent = referral.bonusPercent();
      uint256 reward = _tokenAmountDeliveredDuringPurchase.mul(bonusPercent).div(100);
      require(MintableToken(token).mint(referralOwner, reward));
      referral.tokensPurchasedCallback(_tokenAmountDeliveredDuringPurchase, reward);
      emit ReferralRewarded(referralOwner, reward);
    }
  }
}
