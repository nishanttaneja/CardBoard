//
//  ViewController.swift
//  CardBoard
//
//  Created by Nishant Taneja on 08/03/21.
//

import UIKit

class ViewController: UIViewController {
    private var cardboardVC = CardBoardViewController(nibName: "CardBoardViewController", bundle: nil)
    private var defaultOriginForCard: CGFloat!
    private var originForCard: CGFloat = 0 {
        didSet {
            cardboardVC.view.frame.origin.y = originForCard
        }
    }
    
    private var runningAnimators = [UIViewPropertyAnimator]()
    private var animatorFractionCompleted: CGFloat = 0
    private var resetAnimators: Bool = false
    
    private var currentCardState: CardState = .collapsed
    private var shouldExpand = true
    private var nextCardState: CardState {
        switch currentCardState {
        case .collapsed: return .expanded
        case .expanded: return shouldExpand ? .fullyExpanded : .collapsed
        case .fullyExpanded: return .expanded
        }
    }
    
}

//MARK:- CardState
extension ViewController {
    private enum CardState {
        case collapsed
        case expanded
        case fullyExpanded
    }
}

//MARK:- Animators
extension ViewController {
    private enum AnimatorType {
        case frame_update
    }
    
    private func animator(ofType type: AnimatorType, withDuration duration: TimeInterval) -> UIViewPropertyAnimator {
        var animator = UIViewPropertyAnimator()
        switch type {
        case .frame_update:
            animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1, animations: {
                let cardStateToUse = self.resetAnimators ? self.currentCardState : self.nextCardState
                print(cardStateToUse)
                switch cardStateToUse {
                case .collapsed:
                    self.originForCard = self.defaultOriginForCard
                case .expanded:
                    self.originForCard = self.view.frame.height - (self.cardboardVC.topView.frame.height + self.cardboardVC.midView.frame.height)
                case .fullyExpanded:
                    let maxHeight = self.view.frame.height - (self.cardboardVC.topView.frame.height + self.cardboardVC.midView.frame.height + self.cardboardVC.bottomView.frame.height)
                    self.originForCard = maxHeight > 120 ? maxHeight : 120
                }
            })
            animator.addCompletion { _ in
                if !self.resetAnimators {
                    self.currentCardState = self.nextCardState
                }
                self.resetAnimators = false
                self.runningAnimators.removeAll()
            }
        }
        return animator
    }
    
    private func runAnimatorsIfNeeded(withDuration duration: TimeInterval) {
        guard runningAnimators.isEmpty else { return }
        let frameUpdateAnimator = animator(ofType: .frame_update, withDuration: duration)
        frameUpdateAnimator.startAnimation()
        runningAnimators.append(frameUpdateAnimator)
    }
    
    private func updateAnimatorsIfRequired(withDuration duration: TimeInterval) {
        stopAllAnimators()
        runAnimatorsIfNeeded(withDuration: duration)
    }
    
    private func stopAllAnimators() {
        runningAnimators.forEach({ $0.stopAnimation(true) })
        runningAnimators.removeAll()
    }
}

//MARK:- View LifeCycle
extension ViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addCardBoard()
        addGestureRecognizers()
    }
}

//MARK:- Gestures
extension ViewController {
    private func addGestureRecognizers() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.allowedScrollTypesMask = .continuous
        cardboardVC.dragger.addGestureRecognizer(panGestureRecognizer)
    }
    
    @objc private func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if runningAnimators.isEmpty {
                runAnimatorsIfNeeded(withDuration: 0.5)
            }
            runningAnimators.forEach { (animator) in
                animator.pauseAnimation()
                animatorFractionCompleted = animator.fractionComplete
            }
        case .changed:
            let translation = recognizer.translation(in: cardboardVC.dragger)
            if currentCardState == .collapsed, translation.y > 0 {
                stopAllAnimators()
                resetAnimators = true
                runAnimatorsIfNeeded(withDuration: 0.5)
            } else if currentCardState == .expanded {
                shouldExpand = translation.y > 0 ? false : true
                stopAllAnimators()
                print(currentCardState, nextCardState)
                runAnimatorsIfNeeded(withDuration: 0.5)
            }
            else if currentCardState == .fullyExpanded, translation.y < 0 {
                stopAllAnimators()
                resetAnimators = true
                runAnimatorsIfNeeded(withDuration: 0.5)
            }
            else {
                runningAnimators.forEach { (animator) in
                    animator.fractionComplete = abs(translation.y/self.view.frame.height) + animatorFractionCompleted
                }
            }
        case .ended:
            runningAnimators.forEach { (animator) in
                animator.continueAnimation(withTimingParameters: .none, durationFactor: 0)
            }
        default: break
        }
    }
}

//MARK:- Configure View
extension ViewController {
    private func addCardBoard() {
        defaultOriginForCard = view.frame.height - 120
        cardboardVC.view.frame = CGRect(x: 0, y: defaultOriginForCard, width: view.frame.width, height: view.frame.height - 120)
        addChild(cardboardVC)
        view.addSubview(cardboardVC.view)
    }
}
