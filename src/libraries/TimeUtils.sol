
/*
TimeUtils library provides:
Time remaining calculations
Vesting period validation
Grace period management
Time range operations
Time-weighted average calculations
Duration formatting utilities

*/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title TimeUtils - Library for time-based calculations
/// @notice Implements time management utilities for receivables
library TimeUtils {
    uint256 constant public SECONDS_PER_DAY = 24 hours;
    uint256 constant public SECONDS_PER_YEAR = 365 days;
    uint256 constant public MIN_VESTING_PERIOD = 7 days;
    uint256 constant public MAX_VESTING_PERIOD = 730 days; // 2 years
    
    struct TimeRange {
        uint256 startTime;
        uint256 endTime;
        uint256 duration;
    }

    /// @notice Calculate remaining time until maturity
    /// @param vestingTimestamp The timestamp when the receivable matures
    /// @return timeRemaining Seconds remaining until maturity
    function calculateTimeRemaining(
        uint256 vestingTimestamp
    ) internal view returns (uint256) {
        if (block.timestamp >= vestingTimestamp) {
            return 0;
        }
        return vestingTimestamp - block.timestamp;
    }

    /// @notice Validate vesting period is within acceptable range
    /// @param vestingPeriod The proposed vesting period in seconds
    /// @return bool Whether the vesting period is valid
    function isValidVestingPeriod(
        uint256 vestingPeriod
    ) internal pure returns (bool) {
        return vestingPeriod >= MIN_VESTING_PERIOD && 
               vestingPeriod <= MAX_VESTING_PERIOD;
    }

    /// @notice Calculate grace period end
    /// @param maturityTimestamp The maturity timestamp
    /// @param gracePeriod The grace period in seconds
    /// @return graceEnd The end of grace period timestamp
    function calculateGracePeriodEnd(
        uint256 maturityTimestamp,
        uint256 gracePeriod
    ) internal pure returns (uint256) {
        return maturityTimestamp + gracePeriod;
    }

    /// @notice Check if a receivable is within its grace period
    /// @param maturityTimestamp The maturity timestamp
    /// @param gracePeriod The grace period in seconds
    /// @return bool Whether currently in grace period
    function isInGracePeriod(
        uint256 maturityTimestamp,
        uint256 gracePeriod
    ) internal view returns (bool) {
        uint256 graceEnd = calculateGracePeriodEnd(
            maturityTimestamp,
            gracePeriod
        );
        return block.timestamp <= graceEnd;
    }

    /// @notice Calculate annualized time factor
    /// @param timeRemaining Seconds remaining until maturity
    /// @return factor Time factor for annual rate calculations
    function calculateAnnualizedTimeFactor(
        uint256 timeRemaining
    ) internal pure returns (uint256) {
        return (timeRemaining * 1e18) / SECONDS_PER_YEAR;
    }

    /// @notice Create a time range structure
    /// @param startTime Start timestamp
    /// @param endTime End timestamp
    /// @return TimeRange structure
    function createTimeRange(
        uint256 startTime,
        uint256 endTime
    ) internal pure returns (TimeRange memory) {
        require(endTime > startTime, "Invalid time range");
        return TimeRange({
            startTime: startTime,
            endTime: endTime,
            duration: endTime - startTime
        });
    }

    /// @notice Check if current time is within a time range
    /// @param range The time range to check
    /// @return bool Whether current time is within range
    function isInTimeRange(
        TimeRange memory range
    ) internal view returns (bool) {
        return block.timestamp >= range.startTime && 
               block.timestamp <= range.endTime;
    }

    /// @notice Calculate time overlap between two ranges
    /// @param range1 First time range
    /// @param range2 Second time range
    /// @return overlap Duration of overlap in seconds
    function calculateTimeOverlap(
        TimeRange memory range1,
        TimeRange memory range2
    ) internal pure returns (uint256) {
        uint256 overlapStart = range1.startTime > range2.startTime ? 
                             range1.startTime : range2.startTime;
        uint256 overlapEnd = range1.endTime < range2.endTime ? 
                           range1.endTime : range2.endTime;
        
        if (overlapEnd <= overlapStart) {
            return 0;
        }
        return overlapEnd - overlapStart;
    }

    /// @notice Calculate time-weighted average
    /// @param values Array of values
    /// @param durations Array of corresponding durations
    /// @return average Time-weighted average value
    function calculateTimeWeightedAverage(
        uint256[] memory values,
        uint256[] memory durations
    ) internal pure returns (uint256) {
        require(
            values.length == durations.length,
            "Array length mismatch"
        );
        require(values.length > 0, "Empty arrays");

        uint256 weightedSum = 0;
        uint256 totalDuration = 0;

        for (uint256 i = 0; i < values.length; i++) {
            weightedSum += values[i] * durations[i];
            totalDuration += durations[i];
        }

        require(totalDuration > 0, "Zero total duration");
        return weightedSum / totalDuration;
    }

    /// @notice Format duration into days
    /// @param durationInSeconds Duration in seconds
    /// @return days Number of days
    function formatDurationDays(
        uint256 durationInSeconds
    ) internal pure returns (uint256) {
        return durationInSeconds / SECONDS_PER_DAY;
    }
}