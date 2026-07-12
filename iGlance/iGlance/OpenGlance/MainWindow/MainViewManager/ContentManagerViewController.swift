//  Copyright (C) 2020  D0miH <https://github.com/D0miH> & Contributors <https://github.com/iglance/OpenGlance/graphs/contributors>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

import Cocoa

class ContentManagerViewController: NSViewController {
    // MARK: -
    // MARK: Outlets
    @IBOutlet private var subViewControllerManager: NSView!

    // MARK: -
    // MARK: Instance Variables
    private(set) var currentViewController: NSViewController?

    // MARK: -
    // MARK: Function Overrides

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        // get the view controller that is currently displayed
        currentViewController = segue.destinationController as? NSViewController
    }

    // MARK: -
    // MARK: Instance Functions

    /**
     * Add the given view controller as a sub-view.
     * - Parameter viewController: The given view controller to display.
     */
    func addNewViewController(viewController: NSViewController) {
        guard currentViewController !== viewController else { return }

        removeCurrentViewController()

        // Keep every page inside the content host. Previously pages were added
        // to the controller's root view with a copied frame, which allowed them
        // to overlap the sidebar and left stale geometry after a resize.
        addChild(viewController)
        let contentView = viewController.view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        subViewControllerManager.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: subViewControllerManager.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: subViewControllerManager.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: subViewControllerManager.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: subViewControllerManager.bottomAnchor)
        ])
        currentViewController = viewController
    }

    /**
     * Removes the current view controller.
     */
    func removeCurrentViewController() {
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()
    }

    /**
     * Displays the given view controller as a sub-view.
     */
    func display(viewController: NSViewController) {
        addNewViewController(viewController: viewController)
    }
}
