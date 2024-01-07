//
//  ScrollLyricsView.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Cocoa
import SwiftWhisper

import CoreGraphics
import Foundation
import AVFoundation

extension Comparable {
    
    func clamped(to limit: ClosedRange<Self>) -> Self {
        return min(max(self, limit.lowerBound), limit.upperBound)
    }
    
    func clamped(to limit: PartialRangeThrough<Self>) -> Self {
        return min(self, limit.upperBound)
    }
    
    func clamped(to limit: PartialRangeFrom<Self>) -> Self {
        return max(self, limit.lowerBound)
    }
}

extension Strideable {
    
    func clamped(to limit: Range<Self>) -> Self {
        guard !limit.isEmpty else {
            preconditionFailure("Range cannot be empty")
        }
        let upperBound = limit.upperBound.advanced(by: -1)
        return min(max(self, limit.lowerBound), upperBound)
    }
    
    func clamped(to limit: PartialRangeUpTo<Self>) -> Self {
        let upperBound = limit.upperBound.advanced(by: -1)
        return min(self, upperBound)
    }
}

// MARK: - Range

extension NSString {
    
    var fullRange: NSRange {
        return NSRange(location: 0, length: length)
    }
}

extension String {
    
    var fullRange: NSRange {
        return NSRange(location: 0, length: utf16.count)
    }
}

extension NSAttributedString {
    
    var fullRange: NSRange {
        return NSRange(location: 0, length: length)
    }
}

extension CharacterSet {
    
    static let hiragana = CharacterSet(charactersIn: "\u{3040}"..<"\u{30a0}")
    static let katakana = CharacterSet(charactersIn: "\u{30a0}"..<"\u{3100}")
    static let kana = CharacterSet(charactersIn: "\u{3040}"..<"\u{3100}")
    static let kanji = CharacterSet(charactersIn: "\u{4e00}"..<"\u{9fc0}")
}

public protocol Then {}

extension Then where Self: Any {
    
    public func with(_ block: (inout Self) throws -> Void) rethrows -> Self {
        var copy = self
        try block(&copy)
        return copy
    }
    
    public func `do`<T>(_ block: (Self) throws -> T) rethrows -> T {
        return try block(self)
    }
    
}

extension Then where Self: AnyObject {
    
    public func then(_ block: (Self) throws -> Void) rethrows -> Self {
        try block(self)
        return self
    }
    
}

extension NSObject: Then {}

extension CGPoint: Then {}
extension CGRect: Then {}
extension CGSize: Then {}
extension CGVector: Then {}


//extension NSString {
//
//    var fullRange: NSRange {
//        return NSRange(location: 0, length: length)
//    }
//}

class LyricsScrollView: NSScrollView {
    
//    weak var delegate: ScrollLyricsViewDelegate?
    
    private let player = Player.global
    
    private var textView: NSTextView {
        // swiftlint:disable:next force_cast
        return documentView as! NSTextView
    }
    
    var fadeStripWidth: CGFloat = 24
    
    @objc dynamic var textColor = #colorLiteral(red: 0.7540688515, green: 0.7540867925, blue: 0.7540771365, alpha: 1) {
        didSet {
            DispatchQueue.main.async {
                let range = self.textView.string.fullRange
                self.textView.textStorage?.addAttribute(.foregroundColor, value: self.textColor, range: range)
                if let highlightedRange = self.highlightedRange {
                    self.textView.textStorage?.addAttribute(.foregroundColor, value: self.highlightColor, range: highlightedRange)
                }
            }
        }
    }
    
    @objc dynamic var highlightColor = #colorLiteral(red: 0.8866666667, green: 1, blue: 0.8, alpha: 1) {
        didSet {
            guard let highlightedRange = self.highlightedRange else { return }
            DispatchQueue.main.async {
                self.textView.textStorage?.addAttribute(.foregroundColor, value: self.highlightColor, range: highlightedRange)
            }
        }
    }
    
    @objc dynamic var fontName = "Helvetica" {
        didSet { updateFont() }
    }
    
    @objc dynamic var fontSize: CGFloat = 18 {
        didSet { updateFont() }
    }
    
    private var ranges: [(TimeInterval, NSRange)] = []
    private var highlightedRange: NSRange?
    
    func addTextAttributes (range: NSRange) {
        let font = NSFont(name: fontName, size: fontSize)!
        let style = NSMutableParagraphStyle().with {
            $0.alignment = .left
        }
        
        textView.textStorage?.addAttributes([
            .foregroundColor: textColor,
            .paragraphStyle: style,
            .font: font
            ], range: range)
    }
    
    func setupTextContents(segments: [Segment]) {
//        removePeriodicTimeObserver()
        var lrcContent = ""
        var newRanges: [(TimeInterval, NSRange)] = []
        
        for line in segments {
            var lineStr = line.text
            
            var startInterval = Double(line.startTime) / 1000.0
            
            // we have to convert startTime to NSTimeInterval
            let range = NSRange(location: lrcContent.utf16.count, length: lineStr.utf16.count)
            newRanges.append((startInterval, range))
            lrcContent += lineStr
            
            if line != segments.last {
                lrcContent += "\n\n"
            }
        }
        

        ranges = newRanges
        textView.string = lrcContent
        highlightedRange = nil
        
        let range = textView.string.fullRange
        addTextAttributes(range: range)

        needsLayout = true
        
        
//        if (timeObserver == nil) {
            print("adding observer")
            addPeriodicTimeObserver()
//        }
    }
    
    private var timeObserver: Any?

    /// Adds an observer of the player timing.
    private func addPeriodicTimeObserver() {
        // Create a 0.5 second interval time.
        let interval = CMTime(value: 1, timescale: 2)
        timeObserver = player.avPlayer?.addPeriodicTimeObserver(forInterval: interval,
                                                      queue: .main) { [weak self] time in
            guard let self else { return }
            // Update the published currentTime and duration values.
            let currentTime = player.avPlayer?.currentItem?.currentTime().seconds ?? 0.0
            
            print("scrolling to \(currentTime)")
            
            self.highlight(position: currentTime)
            self.scroll(position: currentTime)
        }
    }
    
    func reset() {
//        removePeriodicTimeObserver()
        self.textView.string = "Not Playing"
        self.addTextAttributes(range: self.textView.string.fullRange)
    }
    
//    private func removePeriodicTimeObserver() {
//        if (timeObserver != nil) {
//            player.avPlayer?.removeTimeObserver(timeObserver)
//        }
//        timeObserver = nil
//    }
    
    override func layout() {
        super.layout()
        updateFadeEdgeMask()
        updateEdgeInset()
    }
    
    override func mouseUp(with event: NSEvent) {
        guard event.clickCount == 2 else {
            super.mouseUp(with: event)
            return
        }
        
        let clickPoint = textView.convert(event.locationInWindow, from: nil)
        let clickRange = ranges.filter { _, range in
            let bounding = textView.layoutManager!.boundingRect(forGlyphRange: range, in: textView.textContainer!)
            return bounding.contains(clickPoint)
        }
        if let (position, _) = clickRange.first {
//            delegate?.doubleClickLyricsLine(at: position)
            player.seek(seconds: position)
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        switch event.momentumPhase {
        case .began:
            return
//            delegate?.scrollWheelDidStartScroll()
        case .ended, .cancelled:
            return
//            delegate?.scrollWheelDidEndScroll()
        default:
            break
        }
    }
    
    // overriding scrollwheel method breaks trackpad responsive scrolling ability
    override class var isCompatibleWithResponsiveScrolling: Bool {
        return true
    }
    
    private func updateFadeEdgeMask() {
        let location = fadeStripWidth / frame.height
        wantsLayer = true
        layer?.mask = CAGradientLayer().then {
            $0.frame = bounds
            $0.colors = [#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)] as [CGColor]
            $0.locations = [0, location as NSNumber, (1 - location) as NSNumber, 1]
            $0.startPoint = .zero
            $0.endPoint = CGPoint(x: 0, y: 1)
        }
    }
    
    private func updateEdgeInset() {
        guard !ranges.isEmpty else {
            return
        }
        
        let bounding1 = textView.layoutManager!.boundingRect(forGlyphRange: ranges.first!.1, in: textView.textContainer!)
        let topInset = frame.height / 2 - bounding1.height / 2
        let bounding2 = textView.layoutManager!.boundingRect(forGlyphRange: ranges.last!.1, in: textView.textContainer!)
        let bottomInset = frame.height / 2 - bounding2.height / 2
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
    }
    
    func highlight(position: TimeInterval) {
        print("highlight position: \(position)")
        guard !ranges.isEmpty else {
            return
        }
        
        var left = ranges.startIndex
        var right = ranges.endIndex - 1
        while left <= right {
            let mid = (left + right) / 2
            if ranges[mid].0 <= position {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        let range = ranges[right.clamped(to: ranges.indices)].1
        
        if highlightedRange == range {
            return
        }
        
        highlightedRange.map { textView.textStorage?.addAttribute(.foregroundColor, value: textColor, range: $0) }
        textView.textStorage?.addAttribute(.foregroundColor, value: highlightColor, range: range)
        
        highlightedRange = range
    }
    
    func scroll(position: TimeInterval) {
        print("scroll position: \(position)")
        guard !ranges.isEmpty else {
            return
        }
        
        var left = ranges.startIndex
        var right = ranges.endIndex - 1
        while left <= right {
            let mid = (left + right) / 2
            if ranges[mid].0 <= position {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        let range = ranges[right.clamped(to: ranges.indices)].1
        
        let bounding = textView.layoutManager!.boundingRect(forGlyphRange: range, in: textView.textContainer!)
        
        let point = NSPoint(x: 0, y: bounding.midY - frame.height / 2)
        textView.scroll(point)
    }
    
    func updateFont() {
        let range = textView.string.fullRange
        let font = NSFont(name: fontName, size: fontSize)!
        textView.textStorage?.addAttribute(.font, value: font, range: range)
    }
}
