//
//  Utilities.swift
//
//
//  Created by Yaroslav Yashin on 11.07.2022.
//

import Foundation
import BigInt

public struct Utilities {


    /// Parse a user-supplied string using the number of decimals for particular Ethereum unit.
    /// If input is non-numeric or precision is not sufficient - returns nil.
    /// Allowed decimal separators are ".", ",".
    public static func parseToBigUInt(_ amount: String, units: Utilities.Units = .ether) -> BigUInt? {
        let unitDecimals = units.decimals
        return parseToBigUInt(amount, decimals: unitDecimals)
    }

    /// Parse a string using the number of decimals.
    /// If input is non-numeric or precision is not sufficient - returns nil.
    /// Allowed decimal separators are ".", ",".
    public static func parseToBigUInt(_ amount: String, decimals: Int = 18) -> BigUInt? {
        let separators = CharacterSet(charactersIn: ".,")
        let components = amount.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: separators)
        guard components.count == 1 || components.count == 2 else { return nil }
        let unitDecimals = decimals
        guard let beforeDecPoint = BigUInt(components[0], radix: 10) else { return nil }
        var mainPart = beforeDecPoint * BigUInt(10).power(unitDecimals)
        if components.count == 2 {
            let numDigits = components[1].count
            guard numDigits <= unitDecimals else { return nil }
            guard let afterDecPoint = BigUInt(components[1], radix: 10) else { return nil }
            let extraPart = afterDecPoint * BigUInt(10).power(unitDecimals-numDigits)
            mainPart += extraPart
        }
        return mainPart
    }

    /// Formats a `BigInt` object to `String`. The supplied number is first divided into integer and decimal part based on `units` value,
    /// then limits the decimal part to `formattingDecimals` symbols and uses a `decimalSeparator` as a separator.
    /// Fallbacks to scientific format if higher precision is required.
    ///
    /// - Parameters:
    ///   - bigNumber: number to format;
    ///   - units: unit to format number to;
    ///   - formattingDecimals: the number of decimals that should be in the final formatted number;
    ///   - decimalSeparator: decimals separator;
    ///   - fallbackToScientific: if should fallback to scienctific representation like `1.23e-10`.
    /// - Returns: formatted number or `nil` if formatting was not possible.
    public static func formatToPrecision(_ bigNumber: BigInt, units: Utilities.Units = .ether, formattingDecimals: Int = 4, decimalSeparator: String = ".", fallbackToScientific: Bool = false) -> String {
        let magnitude = bigNumber.magnitude
        let formatted = formatToPrecision(magnitude, units: units, formattingDecimals: formattingDecimals, decimalSeparator: decimalSeparator, fallbackToScientific: fallbackToScientific)
        switch bigNumber.sign {
        case .plus:
            return formatted
        case .minus:
            return "-" + formatted
        }
    }

    /// Formats a `BigUInt` object to `String`. The supplied number is first divided into integer and decimal part based on `units` value,
    /// then limits the decimal part to `formattingDecimals` symbols and uses a `decimalSeparator` as a separator.
    /// Fallbacks to scientific format if higher precision is required.
    ///
    /// - Parameters:
    ///   - bigNumber: number to format;
    ///   - units: unit to format number to;
    ///   - formattingDecimals: the number of decimals that should be in the final formatted number;
    ///   - decimalSeparator: decimals separator;
    ///   - fallbackToScientific: if should fallback to scienctific representation like `1.23e-10`.
    /// - Returns: formatted number or `nil` if formatting was not possible.
    public static func formatToPrecision(_ bigNumber: BigUInt, units: Utilities.Units = .ether, formattingDecimals: Int = 4, decimalSeparator: String = ".", fallbackToScientific: Bool = false) -> String {
        guard bigNumber != 0 else {
            return "0"
        }
        let unitDecimals = units.decimals
        var toDecimals = formattingDecimals
        if unitDecimals < toDecimals {
            toDecimals = unitDecimals
        }
        let divisor = BigUInt(10).power(unitDecimals)
        let (quotient, remainder) = bigNumber.quotientAndRemainder(dividingBy: divisor)

        guard toDecimals != 0 else {
            return "\(quotient)"
        }

        let remainderStr = "\(remainder)"
        let fullPaddedRemainder = remainderStr.leftPadding(toLength: unitDecimals, withPad: "0")
        let remainderPadded = fullPaddedRemainder[0..<toDecimals]

        guard remainderPadded == String(repeating: "0", count: toDecimals) else {
            return "\(quotient)" + decimalSeparator + remainderPadded
        }

        if fallbackToScientific {
            return formatToScientificRepresentation(remainderStr, remainder: fullPaddedRemainder, decimals: formattingDecimals, decimalSeparator: decimalSeparator)
        }

        guard quotient == 0 else {
            return "\(quotient)"
        }

        return "\(quotient)" + decimalSeparator + remainderPadded
    }

    private static func formatToScientificRepresentation(_ remainder: String, remainder fullPaddedRemainder: String, decimals: Int, decimalSeparator: String) -> String {
        var remainder = remainder
        var firstDigit = 0
        for char in fullPaddedRemainder {
            if char == "0" {
                firstDigit += 1
            } else {
                let firstDecimalUnit = String(fullPaddedRemainder[firstDigit ..< firstDigit + 1])
                var remainingDigits = ""
                let numOfRemainingDecimals = fullPaddedRemainder.count - firstDigit - 1
                if numOfRemainingDecimals <= 0 {
                    remainingDigits = ""
                } else if numOfRemainingDecimals > decimals {
                    let end = firstDigit + 1 + decimals > fullPaddedRemainder.count ? fullPaddedRemainder.count : firstDigit + 1 + decimals
                    remainingDigits = String(fullPaddedRemainder[firstDigit + 1 ..< end])
                } else {
                    remainingDigits = String(fullPaddedRemainder[firstDigit + 1 ..< fullPaddedRemainder.count])
                }
                if !remainingDigits.isEmpty {
                    remainder = firstDecimalUnit + decimalSeparator + remainingDigits
                } else {
                    remainder = firstDecimalUnit
                }
                firstDigit += 1
                break
            }
        }
        return remainder + "e-" + String(firstDigit)
    }

    /// Marshals the V, R and S signature parameters into a 65 byte recoverable EC signature.
    static func marshalSignature(v: UInt8, r: [UInt8], s: [UInt8]) -> Data? {
        guard r.count == 32, s.count == 32 else { return nil }
        var completeSignature = Data(r)
        completeSignature.append(Data(s))
        completeSignature.append(Data([v]))
        return completeSignature
    }

}

extension Utilities {
    /// Various units used in Ethereum ecosystem
    public enum Units {
        case wei
        case kwei
        case babbage
        case femtoether
        case mwei
        case lovelace
        case picoether
        case gwei
        case shannon
        case nanoether
        case nano
        case microether
        case szabo
        case micro
        case finney
        case milliether
        case milli
        case ether
        case kether
        case grand
        case mether
        case gether
        case tether
        case custom(Int)

        public var decimals: Int {
            switch self {
            case .wei:
                return 0
            case .kwei, .babbage, .femtoether:
                return 3
            case .mwei, .lovelace, .picoether:
                return 6
            case .gwei, .shannon, .nanoether, .nano:
                return 9
            case .microether, .szabo, .micro:
                return 12
            case .finney, .milliether, .milli:
                return 15
            case .ether:
                return 18
            case .kether, .grand:
                return 21
            case .mether:
                return 24
            case .gether:
                return 27
            case .tether:
                return 30
            case .custom(let decimals):
                return max(0, decimals)
            }
        }
    }
}
