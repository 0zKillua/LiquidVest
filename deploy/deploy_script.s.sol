// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployScript} from "forge-std/DeployScript.sol";

contract DeployScript is DeployScript {
    function run() internal {
        vm.startBroadcast();

        // Deploy BaseReceivable contract
        BaseReceivable receivable = new BaseReceivable();

        // Deploy DiscountCalculator contract
        DiscountCalculator calculator = new DiscountCalculator();

        // Deploy PrimaryMarket contract
        PrimaryMarket primaryMarket = new PrimaryMarket(
            address(receivable),
            address(calculator)
        );

        // Deploy SecondaryMarket contract
        SecondaryMarket secondaryMarket = new SecondaryMarket(
            address(receivable),
            address(calculator)
        );

        // Deploy PayoutManager contract
        PayoutManager payoutManager = new PayoutManager(
            address(receivable),
            address(new EscrowVault(address(receivable)))
        );

        // Deploy ProtocolConfig contract
        ProtocolConfig config = new ProtocolConfig();

        vm.stopBroadcast();
    }
}