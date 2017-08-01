//
//  DeckPresentationController.swift
//  DeckTransition
//
//  Created by Harshil Shah on 15/10/16.
//  Copyright © 2016 Harshil Shah. All rights reserved.
//

import UIKit

/**
 Delegate that communicates to the `DeckPresentationController`
 whether the dismiss by pan gesture is enabled
*/
protocol DeckPresentationControllerDelegate {
    func isDismissGestureEnabled() -> Bool
}

final class DeckPresentationController: UIPresentationController, UIGestureRecognizerDelegate {
	
	// MARK:- Constants
	
	/**
	 As best as I can tell using my iPhone and a bunch of iOS UI templates I
	 came across online, 28 points is the distance between the top edge of the
	 screen and the top edge of the modal view
	*/
	let offset: CGFloat = 28
	
	// MARK:- Internal variables
	
    var transitioningDelegate: DeckPresentationControllerDelegate?
    var pan: UIPanGestureRecognizer?
	
	// MARK:- Private variables
	
	private var backgroundView: UIView?
	private var presentingViewSnapshotView: UIView?
	private var cachedContainerWidth: CGFloat = 0
	private var aspectRatioConstraint: NSLayoutConstraint?
	
	private var presentAnimation: (() -> ())? = nil
	private var presentCompletion: ((Bool) -> ())? = nil
	private var dismissAnimation: (() -> ())? = nil
	private var dismissCompletion: ((Bool) -> ())? = nil
	
	// MARK:- Initializers
	
	convenience init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?, presentAnimation: (() -> ())? = nil, presentCompletion: ((Bool) ->())? = nil, dismissAnimation: (() -> ())? = nil, dismissCompletion: ((Bool) -> ())? = nil) {
		self.init(presentedViewController: presentedViewController, presenting: presentingViewController)
		self.presentAnimation = presentAnimation
		self.presentCompletion = presentCompletion
		self.dismissAnimation = dismissAnimation
		self.dismissCompletion = dismissCompletion
		
		NotificationCenter.default.addObserver(self, selector: #selector(updateForStatusBar), name: .UIApplicationDidChangeStatusBarFrame, object: nil)
	}
	
    override var frameOfPresentedViewInContainerView: CGRect {
        if let view = containerView {
            return CGRect(x: 0, y: offset, width: view.bounds.width, height: view.bounds.height - offset)
        } else {
            return .zero
        }
    }
	
	// MARK:- Presentation

    /**
     Method to ensure the layout is as required at the end of the presentation.
     This is required in case the modal is presented without animation.
    
     It also sets up the gesture recognizer to handle dismissal of the modal view
     controller by panning downwards
    */
    override func presentationTransitionDidEnd(_ completed: Bool) {
		guard let containerView = containerView else {
			return
		}
		
        if completed {
            presentedViewController.view.frame = frameOfPresentedViewInContainerView
            presentedViewController.view.round(corners: [.topLeft, .topRight], withRadius: 8)
			presentAnimation?()
			
			presentingViewSnapshotView = UIView()
			presentingViewSnapshotView!.translatesAutoresizingMaskIntoConstraints = false
			containerView.insertSubview(presentingViewSnapshotView!, belowSubview: presentedViewController.view)
			
			NSLayoutConstraint.activate([
				presentingViewSnapshotView!.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
				presentingViewSnapshotView!.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
				presentingViewSnapshotView!.heightAnchor.constraint(equalTo: containerView.heightAnchor, constant: -40),
			])
			
			updateSnapshotView()
			
			backgroundView = UIView()
			backgroundView!.backgroundColor = .black
			backgroundView!.translatesAutoresizingMaskIntoConstraints = false
			containerView.insertSubview(backgroundView!, belowSubview: presentingViewSnapshotView!)
			
			NSLayoutConstraint.activate([
				backgroundView!.topAnchor.constraint(equalTo: containerView.window!.topAnchor),
				backgroundView!.leftAnchor.constraint(equalTo: containerView.window!.leftAnchor),
				backgroundView!.rightAnchor.constraint(equalTo: containerView.window!.rightAnchor),
				backgroundView!.bottomAnchor.constraint(equalTo: containerView.window!.bottomAnchor)
			])
			
			presentingViewController.view.transform = .identity
			
            pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            pan!.delegate = self
            pan!.maximumNumberOfTouches = 1
            presentedViewController.view.addGestureRecognizer(pan!)
        }
		
		presentCompletion?(completed)
    }
	
	// MARK:- Layout update methods
    
    /**
     Function to handle the modal setup's response to a change in constraints
     Basically the same changes as with the presentation animation are performed here.
    */
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
		
        coordinator.animate(
            alongsideTransition: { [weak self] context in
				guard let `self` = self else {
					return
				}
				
                let frame = CGRect(x: 0, y: self.offset, width: size.width, height: size.height - self.offset)
                self.presentedViewController.view.frame = frame
                self.presentedViewController.view.mask = nil
                self.presentedViewController.view.round(corners: [.topLeft, .topRight], withRadius: 8)
			}, completion: { _ in 
				self.updateSnapshotView()
			}
        )
    }
	
	@objc func updateForStatusBar() {
		guard let containerView = containerView else {
			return
		}
		
		presentingViewController.view.alpha = 0
		
		let fullHeight = containerView.window!.frame.size.height
		let statusBarHeight = UIApplication.shared.statusBarFrame.height - 20
		
		let currentHeight = containerView.frame.height
		let newHeight = fullHeight - statusBarHeight
		
		UIView.animate(
			withDuration: 0.1,
			animations: {
				containerView.frame.origin.y -= newHeight - currentHeight
		}, completion: { [weak self] _ in
			self?.presentingViewController.view.alpha = 1
			containerView.frame = CGRect(x: 0, y: statusBarHeight, width: containerView.frame.width, height: newHeight)
			self?.presentedViewController.view.mask = nil
			self?.presentedViewController.view.round(corners: [.topLeft, .topRight], withRadius: 8)
			}
		)
		
		updateSnapshotView()
	}
	
	private func updateSnapshotView() {
		guard
			let containerView = containerView,
			let presentingViewSnapshotView = presentingViewSnapshotView,
			cachedContainerWidth != containerView.bounds.width
		else {
			return
		}
		
		cachedContainerWidth = containerView.bounds.width
		aspectRatioConstraint?.isActive = false
		let aspectRatio = containerView.bounds.width / containerView.bounds.height
		aspectRatioConstraint = presentingViewSnapshotView.widthAnchor.constraint(equalTo: presentingViewSnapshotView.heightAnchor, multiplier: aspectRatio)
		aspectRatioConstraint?.isActive = true
		
		if let snapshotView = presentingViewController.view.snapshotView(afterScreenUpdates: true) {
			presentingViewSnapshotView.subviews.forEach { $0.removeFromSuperview() }
			
			snapshotView.translatesAutoresizingMaskIntoConstraints = false
			presentingViewSnapshotView.addSubview(snapshotView)
			
			NSLayoutConstraint.activate([
				snapshotView.topAnchor.constraint(equalTo: presentingViewSnapshotView.topAnchor),
				snapshotView.leftAnchor.constraint(equalTo: presentingViewSnapshotView.leftAnchor),
				snapshotView.rightAnchor.constraint(equalTo: presentingViewSnapshotView.rightAnchor),
				snapshotView.bottomAnchor.constraint(equalTo: presentingViewSnapshotView.bottomAnchor)
			])
		}
	}
	
	// MARK:- Dismissal
	
	override func dismissalTransitionWillBegin() {
		let scale: CGFloat = 1 - (40/presentingViewController.view.frame.height)
		presentingViewController.view.transform = CGAffineTransform(scaleX: scale, y: scale)
		presentingViewSnapshotView?.alpha = 0
		backgroundView?.alpha = 0
	}
	
	/**
	Method to ensure the layout is as required at the end of the dismissal.
	This is required in case the modal is dismissed without animation.
	*/
	override func dismissalTransitionDidEnd(_ completed: Bool) {
		if completed {
			presentingViewController.view.frame = containerView!.frame
			presentingViewController.view.transform = .identity
			presentingViewController.view.layer.cornerRadius = 0
			dismissAnimation?()
			
			if let view = containerView {
				let offScreenFrame = CGRect(x: 0, y: view.bounds.height, width: view.bounds.width, height: view.bounds.height)
				presentedViewController.view.frame = offScreenFrame
				presentedViewController.view.transform = .identity
			}
		}
		
		dismissCompletion?(completed)
	}
	
	// MARK:- Gesture handling
	
    @objc private func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(pan) else {
            return
        }
        
        switch gestureRecognizer.state {
        
        case .began:
            gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: containerView)
        
        case .changed:
            if let view = presentedView {
                /**
                 The dismiss gesture needs to be enabled for the pan gesture
                 to do anything.
                */
                if transitioningDelegate?.isDismissGestureEnabled() ?? false {
                    let translation = gestureRecognizer.translation(in: view)
                    updatePresentedViewForTranslation(inVerticalDirection: translation.y)
                } else {
                    gestureRecognizer.setTranslation(.zero, in: view)
                }
            }
        
        case .ended:
            UIView.animate(
                withDuration: 0.25,
                animations: {
                    self.presentedView?.transform = .identity
                }
            )
        
        default: break
        
        }
    }
    
    /**
     Function to update the modal view for a particular amount of
     translation by panning in the vertical direction.
     
     The translation of the modal view is proportional to the panning
     distance until the `elasticThreshold`, after which it increases
     at a slower rate, given by `elasticFactor`, to indicate that the
     `dismissThreshold` is nearing.
     
     Once the `dismissThreshold` is reached, the modal view controller
     is dismissed.
     
     - parameter translation: The translation of the user's pan
     gesture in the container view in the vertical direction
    */
    private func updatePresentedViewForTranslation(inVerticalDirection translation: CGFloat) {
        
        let elasticThreshold: CGFloat = 120
		let dismissThreshold: CGFloat = 240
		
		let translationFactor: CGFloat = 1/2
		
        /**
         Nothing happens if the pan gesture is performed from bottom
         to top i.e. if the translation is negative
        */
        if translation >= 0 {
            let translationForModal: CGFloat = {
                if translation >= elasticThreshold {
					let frictionLength = translation - elasticThreshold
					let frictionTranslation = 30 * atan(frictionLength/120) + frictionLength/10
                    return frictionTranslation + (elasticThreshold * translationFactor)
                } else {
                    return translation * translationFactor
                }
            }()
			
            presentedView?.transform = CGAffineTransform(translationX: 0, y: translationForModal)
            
            if translation >= dismissThreshold {
                presentedViewController.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate methods
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer.isEqual(pan) else {
            return false
        }
		
        return true
    }
    
}
