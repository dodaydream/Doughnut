/*
 * Doughnut Podcast Client
 * Copyright (C) 2017 - 2022 Chris Dyer
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import Cocoa
import Combine

extension Notification.Name {
    static let reloadAll = Notification.Name("reloadAll")
    static let toggleSideView = Notification.Name("toggleSideView")
}

final class WindowController: NSWindowController, NSTextFieldDelegate {
    
    @IBOutlet weak var filterEpisodesToolbarItem: NSToolbarItem!
    @IBOutlet weak var playerView: NSToolbarItem!
    @IBOutlet weak var searchInputView: NSTextField!
    
    @IBOutlet weak var episodeInfoButton: NSButton!
    @IBOutlet weak var transcriptButton: NSButton!

    // what is being displayed on the rhs view
    @Published var currentRhsView: DetailViewState = DetailViewState(rawValue: Preference.integer(for: .rightViewState)) ?? .info
    
    var cancellables = Set<AnyCancellable>()
    
    @IBAction func toggleEpisodeInfo(_ sender: Any) {
        currentRhsView = (currentRhsView == .info) ? .hidden : .info
    }
    
    @IBAction func toggleTranscript(_ sender: Any) {
        currentRhsView = (currentRhsView == .transcript) ? .hidden : .transcript
    }
    
    var viewController: ViewController? {
        return contentViewController as? ViewController
    }
    
    var subscribeViewController: SubscribeViewController {
        get {
            return self.storyboard!.instantiateController(withIdentifier: "SubscribeViewController") as! SubscribeViewController
        }
    }
    
    private func handleToolbarButtonState() {
        
        let _ = $currentRhsView
            .map({ value -> (NSControl.StateValue, NSControl.StateValue) in
                switch value {
                    case .info:
                        return (.on, .off)
                    case .transcript:
                        return (.off, .on)
                    case .hidden:
                        return (.off, .off)
                }
            })
            .sink { [weak self] (infoState, transcriptState) in
                self?.episodeInfoButton.state = infoState
                self?.transcriptButton.state = transcriptState
            }.store(in: &cancellables)
        
        let _ = $currentRhsView
            .sink { [weak self] value in
                self?.viewController?.setDetailViewState(state: value)
                Preference.set(value.rawValue, for: .rightViewState)
            }.store(in: &cancellables)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.titleVisibility = .hidden
        window?.center()
        
        if #available(macOS 11.0, *) {
            window?.toolbarStyle = .unified
        } else {
            window?.styleMask.remove(.fullSizeContentView)
        }
        
        window?.toolbar?.centeredItemIdentifier = playerView.itemIdentifier
        
        // https://stackoverflow.com/questions/65723318/how-to-set-initial-width-of-nssearchtoolbaritem
        searchInputView.addConstraint(
            searchInputView.widthAnchor.constraint(lessThanOrEqualToConstant: 180)
        )
        
        searchInputView.delegate = self
        
        // handle toolbar state
        handleToolbarButtonState()
    }
    
    // Subscribed to Search input changes
    func controlTextDidChange(_ obj: Notification) {
        if !searchInputView.stringValue.isEmpty {
            viewController?.search(searchInputView.stringValue.lowercased())
        } else {
            viewController?.search(nil)
        }
    }
    
    @IBAction func subscribeToPodcast(_ sender: Any) {
        /*let subscribeAlert = NSAlert()
         subscribeAlert.messageText = "Podcast feed URL"
         subscribeAlert.addButton(withTitle: "Ok")
         subscribeAlert.addButton(withTitle: "Cancel")
         
         let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
         input.stringValue = ""
         
         subscribeAlert.accessoryView = input
         let button = subscribeAlert.runModal()
         if button == .alertFirstButtonReturn {
         Library.global.subscribe(url: input.stringValue)
         }*/
        
        contentViewController?.presentAsSheet(subscribeViewController)
    }
    
    @IBAction func reloadAll(_ sender: Any) {
        Library.global.reloadAll()
    }
    
    @IBAction func newPodcast(_ sender: Any) {
        guard let podcastWindowController = ShowPodcastWindowController.instantiateFromMainStoryboard(),
              let podcastWindow = podcastWindowController.window
        else {
            return
        }
        self.window?.beginSheet(podcastWindow, completionHandler: nil)
    }
    
    @IBAction func showDownloads(_ button: NSButton) {
        /*guard let downloadsViewController = self.downloadsViewController else { return }
         
         let popover = NSPopover()
         popover.behavior = .transient
         popover.contentViewController = downloadsViewController
         popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)*/
    }
    
}

extension WindowController: NSWindowDelegate {
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        viewController?.updateWindowTitleVisibility()
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        viewController?.updateWindowTitleVisibility()
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if let player = playerView.view as? PlayerView {
            player.needsDisplay = true
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        if let player = playerView.view as? PlayerView {
            player.needsDisplay = true
        }
    }
    
}
