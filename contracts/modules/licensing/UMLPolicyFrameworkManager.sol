// // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

// external
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { IUMLPolicyFrameworkManager, UMLPolicy } from "contracts/interfaces/licensing/IUMLPolicyFrameworkManager.sol";
import { IPolicyFrameworkManager } from "contracts/interfaces/licensing/IPolicyFrameworkManager.sol";
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { LicensorApprovalManager } from "contracts/modules/licensing/parameter-helpers/LicensorApprovalManager.sol";

// external
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title UMLPolicyFrameworkManager
/// @notice This is the UML Policy Framework Manager, which implements the UML Policy Framework
/// logic for encoding and decoding UML policies into the LicenseRegistry and verifying
/// the licensing parameters for linking, minting, and transferring.
contract UMLPolicyFrameworkManager is
    IUMLPolicyFrameworkManager,
    BasePolicyFrameworkManager,
    ILinkParamVerifier,
    IMintParamVerifier,
    ITransferParamVerifier,
    LicensorApprovalManager
{
    constructor(
        address accessController,
        address licRegistry,
        string memory licenseUrl
    ) BasePolicyFrameworkManager(licRegistry, licenseUrl) LicensorApprovalManager(accessController) {}

    function licenseRegistry()
        external
        view
        override(BasePolicyFrameworkManager, IPolicyFrameworkManager)
        returns (address)
    {
        return address(LICENSE_REGISTRY);
    }

    /// @notice Adds a new policy to the registry
    /// @dev Must encode the policy into bytes to be stored in the LicenseRegistry
    /// @param umlPolicy UMLPolicy compliant licensing term values
    function addPolicy(UMLPolicy calldata umlPolicy) external returns (uint256 policyId) {
        if (policyFrameworkId == 0) {
            revert Errors.PolicyFramework_FrameworkNotYetRegistered();
        }
        _verifyComercialUse(umlPolicy);
        _verifyDerivatives(umlPolicy);
        Licensing.Policy memory protocolPolicy = Licensing.Policy({
            policyFrameworkId: policyFrameworkId,
            data: abi.encode(umlPolicy)
        });
        emit UMLPolicyAdded(policyId, umlPolicy);
        return LICENSE_REGISTRY.addPolicy(protocolPolicy);
    }

    /// @notice Fetchs a policy from the registry, decoding the raw bytes into a UMLPolicy struct
    /// @param policyId  The ID of the policy to fetch
    /// @return policy The UMLPolicy struct
    function getPolicy(uint256 policyId) public view returns (UMLPolicy memory policy) {
        Licensing.Policy memory protocolPolicy = LICENSE_REGISTRY.policy(policyId);
        if (protocolPolicy.policyFrameworkId != policyFrameworkId) {
            revert Errors.LicenseRegistry__FrameworkNotFound();
        }
        policy = abi.decode(protocolPolicy.data, (UMLPolicy));
    }

    function policyToJson(bytes memory policyData) public view returns (string memory) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));

        /* solhint-disable */
        // Follows the OpenSea standard for JSON metadata

        // base json
        string memory json = string(
            '{"name": "Story Protocol License NFT", "description": "License agreement stating the terms of a Story Protocol IPAsset", "attributes": ['
        );

        // bool attribution;
        // bool transferable;
        // bool commercialUse;
        // bool commercialAttribution;
        // string[] commercializers;
        // uint256 commercialRevShare;
        // bool derivativesAllowed;
        // bool derivativesAttribution;
        // bool derivativesApproval;
        // bool derivativesReciprocal;
        // uint256 derivativesRevShare;
        // string[] territories;
        // string[] distributionChannels;

        // Attributions
        json = string(
            abi.encodePacked(
                json,
                '{"trait_type": "Attribution", "value": "',
                policy.attribution ? "true" : "false",
                '"},',
                '{"trait_type": "Transferable", "value": "',
                policy.transferable ? "true" : "false",
                '"},',
                '{"trait_type": "Commerical Use", "value": "',
                policy.commercialUse ? "true" : "false",
                '"},',
                '{"trait_type": "commercialAttribution", "value": "',
                policy.commercialAttribution ? "true" : "false",
                '"},',
                '{"trait_type": "commercialRevShare", "value": ',
                Strings.toString(policy.commercialRevShare),
                "},"
                '{"trait_type": "commercializers", "value": ['
            )
        );

        uint256 commercializerCount = policy.commercializers.length;
        for (uint256 i = 0; i < commercializerCount; ++i) {
            json = string(abi.encodePacked(json, '"', policy.commercializers[i], '"'));
            if (i != commercializerCount - 1) {
                json = string(abi.encodePacked(json, ","));
            }
        }

        json = string(
            abi.encodePacked(
                json,
                ']}, {"trait_type": "derivativesAllowed", "value": "',
                policy.derivativesAllowed ? "true" : "false",
                '"},',
                '{"trait_type": "derivativesAttribution", "value": "',
                policy.derivativesAttribution ? "true" : "false",
                '"},',
                '{"trait_type": "derivativesApproval", "value": "',
                policy.derivativesApproval ? "true" : "false",
                '"},',
                '{"trait_type": "derivativesReciprocal", "value": "',
                policy.derivativesReciprocal ? "true" : "false",
                '"},',
                '{"trait_type": "derivativesRevShare", "value": ',
                Strings.toString(policy.derivativesRevShare),
                "},"
                '{"trait_type": "territories", "value": ['
            )
        );

        uint256 territoryCount = policy.territories.length;
        for (uint256 i = 0; i < territoryCount; ++i) {
            json = string(abi.encodePacked(json, '"', policy.territories[i], '"'));
            if (i != territoryCount - 1) {
                json = string(abi.encodePacked(json, ","));
            }
        }

        json = string(abi.encodePacked(json, ']}, {"trait_type": "distributionChannels", "value": ['));

        uint256 distributionChannelCount = policy.distributionChannels.length;
        for (uint256 i = 0; i < distributionChannelCount; ++i) {
            json = string(abi.encodePacked(json, '"', policy.distributionChannels[i], '"'));
            if (i != distributionChannelCount - 1) {
                json = string(abi.encodePacked(json, ","));
            }
        }

        json = string(abi.encodePacked(json, "]}]}"));
        /* solhint-enable */

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(BasePolicyFrameworkManager, IERC165) returns (bool) {
        return
            super.supportsInterface(interfaceId) ||
            interfaceId == type(ILinkParamVerifier).interfaceId ||
            interfaceId == type(IMintParamVerifier).interfaceId ||
            interfaceId == type(ITransferParamVerifier).interfaceId;
    }

    function verifyLink(
        uint256 licenseId,
        address,
        address ipId,
        address,
        bytes calldata policyData
    ) external override onlyLicenseRegistry returns (bool) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));
        bool linkingOK = true;
        // If the policy defines commercial revenue sharing, call the royalty module
        // to set it for the licensor
        if (policy.commercialRevShare > 0) {
            // RoyaltyModule.setRevShare()
        }
        // If the policy defines derivative revenue sharing, call the royalty module
        // to set it for the licensor in future derivatives
        if (policy.derivativesRevShare > 0) {
            // RoyaltyModule.setRevShareForDerivatives()
        }
        // If the policy defines the licensor must approve derivatives, check if the
        // derivative is approved by the licensor
        if (policy.derivativesApproval) {
            linkingOK = linkingOK && isDerivativeApproved(licenseId, ipId);
        }
        return linkingOK;
    }

    function verifyMint(
        address,
        bool policyWasInherited,
        address,
        address,
        uint256,
        bytes memory policyData
    ) external onlyLicenseRegistry returns (bool) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));
        // TODO:
        // If the policy defines no derivative is allowed, and policy was inherited,
        // we don't allow minting
        if (!policy.derivativesAllowed && policyWasInherited) {
            return false;
        }
        return true;
    }

    function verifyTransfer(
        uint256 licenseId,
        address from,
        address,
        uint256,
        bytes memory policyData
    ) external onlyLicenseRegistry returns (bool) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));
        // If license is non-transferable, only the licensor can transfer out a license
        // (or be directly minted to someone else)
        if (!policy.transferable) {
            // True if from == licensor
            return from == LICENSE_REGISTRY.licensorIpId(licenseId);
        }
        return true;
    }

    /// Checks the configuration of commercial use and throws if the policy is not compliant
    /// @param policy The policy to verify
    function _verifyComercialUse(UMLPolicy calldata policy) internal view {
        if (!policy.commercialUse) {
            if (policy.commercialAttribution) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddAttribution();
            }
            if (policy.commercializers.length > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddCommercializers();
            }
            if (policy.commercialRevShare > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddRevShare();
            }
            if (policy.derivativesRevShare > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddDerivRevShare();
            }
        }
    }

    /// Checks the configuration of derivative parameters and throws if the policy is not compliant
    /// @param policy The policy to verify
    function _verifyDerivatives(UMLPolicy calldata policy) internal pure {
        if (!policy.derivativesAllowed) {
            if (policy.derivativesAttribution) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddAttribution();
            }
            if (policy.derivativesApproval) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddApproval();
            }
            if (policy.derivativesReciprocal) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddReciprocal();
            }
            if (policy.derivativesRevShare > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddRevShare();
            }
        }
    }
}