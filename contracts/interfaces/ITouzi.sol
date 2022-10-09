//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ITouzi {
    // -------------------------------------------------------------------
    // Platform functions
    // -------------------------------------------------------------------

    struct PlatformConfig {
        address payment;            // Address to receive payments
        address admin;              // Admin address of the platform
        uint256 feeRate;            // 0.1% = 1e15, 1% = 1e16, 10% = 1e17
    }

    // get platform config
    function getPlatformConfig() external view returns (PlatformConfig memory);

    // set platform config
    function setPlatformConfig(PlatformConfig memory config) external;

    // withdraw all platform fee
    function withdrawPlatformFee() external;


    // -------------------------------------------------------------------
    // Merchant functions
    // -------------------------------------------------------------------
    struct Machine {

    }

    // Create a new Channel, any user can create a channel
    // @return channelID
    function createChannel() external returns (uint256);

    // Delete a channel, only the channel owner can delete it
    // All machines in the channel will be deleted
    function deleteChannel(uint256 _channelId) external;

    // Create a new Machine, only the channel owner can create a machine
    function createMachine(uint256 _channelId, Machine config) external;

    // Delete a Machine, only the channel owner can delete it
    function deleteMachine(uint256 _channelId, uint256 _machineId) external;

    // Get Machine Info
    // @return machine info
    function getMachineInfo(uint256 _channelId, uint256 _machineId) external view returns (Machine memory);

    // Withdraw all channel fee
    function withdrawMachineFee(uint256 _channelId) external;


    // -------------------------------------------------------------------
    // Player functions
    // -------------------------------------------------------------------

    // Roll, will makeRequestUint256()
    function roll(uint256 _channelId, uint256 _machineId) external;
}