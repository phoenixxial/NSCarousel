//
//  NSCarouselView.swift
//
//  Created by Nik Suprunov on 3/1/20.
//  Copyright © 2020 Nik Suprunov. All rights reserved.
//

import UIKit

public struct NSCarouselSettings {
    let borderColor: UIColor = .clear
    let borderWidth: CGFloat = 0
    let innerItemsInteractable: Bool = false
    let doubleSidedItems: Bool = true
    var defaultCardSize: CGSize = .zero
    ///Should be used if views overlap  on 2D transform
    let shouldDisableNeighborInteraction: Bool = true
}


public protocol NSCarouselViewDelegate: class  {
    func prepareCard(_ index: Int) -> UIView
    func numberOfItems() -> Int
    func sizeForCard() -> CGSize
    func didScroll(to index: Int) -> Void
}

public class NSCarouselView: UIView {
    
    private var supportingViews = [UIView]()
    private var transformLayer = CATransformLayer()
    private var carouselGestureRecognizer: UIPanGestureRecognizer!
    
    private var currentAngle: CGFloat = 0
    private var currentOffset: CGFloat = 0
    private var speedingFactor: CGFloat = 0.35
    public private(set) var numberOfItems: Int = 0
    private var settings = NSCarouselSettings()
    
    private var segmentLength: CGFloat {
        get {
            return CGFloat(360/self.numberOfItems)
        }
    }
    
    
    ///Return the "most visible item"
    public var currentView: UIView? {
        get {
            if currentIndex > 0 && currentIndex < numberOfItems {
                return supportingViews[currentIndex]
            }
            return nil
        }
    }
    
    ///Returns the index of the "most visible item"
    private(set) var currentIndex = 0
    
    public weak var delegate: NSCarouselViewDelegate? = nil {
        didSet {
            self.reloadData()
        }
    }
    
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.isUserInteractionEnabled = true
        transformLayer.frame = self.bounds
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = true
        transformLayer.frame = self.bounds
    }
    
    //MARK:- Private
    
    private func setupViews() {
        
        guard let del = delegate, del.numberOfItems() > 0 else { return }
        self.numberOfItems = del.numberOfItems()
        let cardSize = del.sizeForCard()
        self.settings.defaultCardSize = cardSize
        for i in 0..<numberOfItems {
            supportingViews.append(del.prepareCard(i))
        }
        
        
        for view in supportingViews {
            view.isUserInteractionEnabled = true
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalToConstant: settings.defaultCardSize.width).isActive = true
            view.heightAnchor.constraint(equalToConstant: settings.defaultCardSize.height).isActive = true
            view.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(view)
            view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(performPanAction(recognizer:))))
        }
        
        carouselGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(performPanAction(recognizer:)))
        viewSelected(at: 0)
        self.layer.addSublayer(self.transformLayer)
        self.turn()
        
        ///Force context switch
        DispatchQueue.main.asyncAfter(deadline: .now()+0.0) { [weak del, weak self] in
            guard let self = self, del === self.delegate else {return}
            
            self.addGestureRecognizer(self.carouselGestureRecognizer)
            self.supportingViews.forEach({self.addSupportingView(myView: $0)})
            self.turn()
        }
    }
    
    private func addSupportingView(myView: UIView) {
        let imageLayer = myView.layer
        imageLayer.frame = CGRect(x: self.center.x - settings.defaultCardSize.width / 2, y: self.frame.height / 2 - settings.defaultCardSize.height / 2, width: settings.defaultCardSize.width, height: settings.defaultCardSize.height)
        imageLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        //imageLayer.contents = view
        imageLayer.contentsGravity = .resizeAspectFill
        
        imageLayer.masksToBounds = true
        
        ///Emulate 3d layer (image now can be visible from both sides)
        imageLayer.isDoubleSided = settings.doubleSidedItems
        
        
        imageLayer.borderColor = settings.borderColor.cgColor
        imageLayer.cornerRadius = settings.borderWidth
        
        transformLayer.addSublayer(imageLayer)
    }
    
    
    private func turn(animDur: Double = 0) {
        guard let transformSublayers = transformLayer.sublayers else { return }
        
        let segmentForIamgeCard: CGFloat = CGFloat(360) / (CGFloat( transformSublayers
            .count))
        
        var angleOffset = currentAngle
        
        for layer in transformSublayers {
            ///Transform matrix for 3D space
            var transform = CATransform3DIdentity
            
            ///This element is responsible for the "depth" of view perspective. Assign a very small value to decide angle: closer value gets too zero, deeper perspective gets.
            transform.m34 = -1 / CGFloat( numberOfItems > 4 ? 125 * numberOfItems : 500)
            
            transform = CATransform3DRotate(transform, degreeToRadians(deg: angleOffset), 0, 1, 0)
            transform = CATransform3DTranslate(transform, 0, 0, CGFloat(numberOfItems > 4 ?  CGFloat(50 * numberOfItems) : 200))
            
            ///When changing layer, animation changes automatically
            CATransaction.setAnimationDuration(0)
            
            if(animDur != 0) {
                UIView.animate(withDuration: animDur) {
                    layer.transform = transform
                    self.layoutSubviews()
                }
            } else {
                layer.transform = transform
            }
            angleOffset += segmentForIamgeCard
        }
    }
    
    @objc private func performPanAction(recognizer: UIPanGestureRecognizer) {
        
        guard numberOfItems > 1 else {return}
        
        var animDuration: Double = 0
        if recognizer.state == .began {
            ///Prevent multiple contexts access the layer modifier at the same time .
            if(currentOffset != 0 ) {
                return
            }
        }
        
        let xOffset = (speedingFactor) * recognizer.translation(in: self).x
        let velocity = recognizer.velocity(in: self).x
        
        guard xOffset < 10000000 || xOffset < -1000000 else { return }
        
        if recognizer.state == .ended || recognizer.state == .cancelled || recognizer.state == .failed {
            
            animDuration = 0.5
            
            var addedValue:CGFloat = velocity < 0 ? -segmentLength : segmentLength
            
            let nextCardOffsetRemainder = (currentOffset).truncatingRemainder(dividingBy: addedValue)
            
            if(abs(nextCardOffsetRemainder) < CGFloat(45/numberOfItems) || (nextCardOffsetRemainder > 0 && addedValue < 0) || (nextCardOffsetRemainder < 0 && addedValue > 0)) {
                addedValue = 0
            }
            
            let totalAddedOffset =  addedValue - nextCardOffsetRemainder
            
            currentOffset += totalAddedOffset
            currentAngle += totalAddedOffset
            
            currentIndex = (currentIndex - Int(currentOffset / segmentLength)).mod(numberOfItems)
            
            turn(animDur: animDuration)
            
            ///Disable all views except "most visible'" one
            viewSelected(at: currentIndex)
            
            ///Reset characteristics to prevent overflow
            currentOffset = 0
            
            delegate?.didScroll(to: currentIndex)
            
        } else {
            let xDiff =  (xOffset) - currentOffset
            currentOffset += xDiff
            currentAngle += xDiff
            turn(animDur: animDuration)
        }
    }
    
    private func viewSelected(at index: Int) {
        
        guard !settings.innerItemsInteractable else {return}
        
        for (ind, view) in supportingViews.enumerated() {
            view.isUserInteractionEnabled = (ind == index)
        }
    }
    
    private func shortestSignedDistance(to index: Int) -> CGFloat {
        /// (currentIndex + t)mod(n) = index  <=> n*t = index- currentIndex
        let d_cyclic = 1*numberOfItems - index + currentIndex
        let d = -index + currentIndex
        if(abs(d_cyclic) > abs(d)) {
            return CGFloat(d)
        } else {
            return CGFloat(d_cyclic)
        }
    }
    
    //MARK:- Public
    
    public func reloadData() {
        self.supportingViews.removeAll()
        self.transformLayer.removeFromSuperlayer()
        self.currentOffset = 0
        self.currentAngle = 0
        self.subviews.forEach { $0.removeFromSuperview() }
        self.layer.sublayers = nil
        self.transformLayer = CATransformLayer()
        setupViews()
    }
    
    public func scrollToCard(at index: Int, animated: Bool) {
        assert( index > 0 && index < numberOfItems)
        
        if( index == currentIndex) {return}
    
        let shortestPath = shortestSignedDistance(to: index)
        
        let totalAddedOffset = segmentLength * shortestPath
        
        currentOffset += totalAddedOffset
        currentAngle += totalAddedOffset
        
        let animationDuration: Double = animated ? max(0.2*Double(abs(currentIndex - index)), 1.0) : 0.0
        
        self.currentIndex = index
        
        turn(animDur: animationDuration)
        
        ///Disable all views except "most visible'" one
        viewSelected(at: currentIndex)
        
        ///Reset characteristics to prevent overflow
        currentOffset = 0
        
        delegate?.didScroll(to: currentIndex)
    }
}


//MARK:- Helper
internal extension Int {
    func mod(_ n: Int) -> Int {
        assert(n > 0, "modulus must be positive")
        let r = self % n
        return r >= 0 ? r : r + n
    }
}

internal func degreeToRadians(deg: CGFloat) -> CGFloat {
    return (deg*CGFloat.pi)/180
}
