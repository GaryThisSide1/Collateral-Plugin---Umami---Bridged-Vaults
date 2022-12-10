pragma solidity ^0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract ReserveProtocolCollateralPlugin {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Address of the Umami Bridged Vaults contract
  address public vaults;

  // Minimum collateralization ratio
  uint256 public minCollateralizationRatio;

  // Map of vault IDs to their corresponding collateralization ratios
  mapping(bytes32 => uint256) public collateralizationRatios;

  constructor(address _vaults, uint256 _minCollateralizationRatio) public {
    vaults = _vaults;
    minCollateralizationRatio = _minCollateralizationRatio;
  }

  // Returns the collateralization ratio for the given vault ID
  function getCollateralizationRatio(bytes32 vaultId) public view returns (uint256) {
    return collateralizationRatios[vaultId];
  }

  // Calculates the required collateral for the given vault and debt
  function calculateRequiredCollateral(bytes32 vaultId, uint256 debt) public view returns (uint256) {
    return debt.mul(collateralizationRatios[vaultId]).div(100);
  }

  // Updates the collateralization ratio for the given vault ID
  function updateCollateralizationRatio(bytes32 vaultId, uint256 ratio) public {
    require(ratio >= minCollateralizationRatio, "Collateralization ratio below minimum");
    collateralizationRatios[vaultId] = ratio;
  }

  // Called by the Umami Bridged Vaults contract to add collateral to a vault
  function addCollateral(bytes32 vaultId, IERC20 collateral, uint256 amount) public {
    require(msg.sender == vaults, "Only the Umami Bridged Vaults contract can call this function");
    require(collateralizationRatios[vaultId] != 0, "Vault does not exist");

    // Calculate the new collateralization ratio
    UmamiBridgedVaults storage vaultsContract = UmamiBridgedVaults(vaults);
    uint256 currentDebt = vaultsContract.getDebt(vaultId);
    uint256 currentCollateral = vaultsContract.getCollateral(vaultId);
    uint256 newCollateralizationRatio = currentCollateral.add(amount).mul(100).div(currentDebt);
    updateCollateralizationRatio(vaultId, newCollateralizationRatio);

    // Transfer the collateral to the vault
    collateral.safeTransfer(vaults, amount);
  }

  // Called by the Umami Bridged Vaults contract to remove collateral from a vault
  function removeCollateral(bytes32 vaultId, IERC20 collateral, uint256 amount) public {
    require(msg.sender == vaults, "Only the Umami Bridged Vaults contract can call this function");
    require(collateralizationRatios[vaultId] != 0, "Vault does not exist");
