import UIKit

public class ARDebugView: UIView {
    let textView = UITextView()
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit(){
        backgroundColor = UIColor.white
        //size self to be a fixed width and height
        NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 200).isActive = true
        NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100).isActive = true
        
        //setup textView
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        self.topAnchor.constraint(equalTo: textView.topAnchor).isActive = true
        self.bottomAnchor.constraint(equalTo: textView.bottomAnchor).isActive = true
        self.leadingAnchor.constraint(equalTo: textView.leadingAnchor).isActive = true
        self.trailingAnchor.constraint(equalTo: textView.trailingAnchor).isActive = true
    }
    
    public func log(_ logText: String){
        var text = textView.text ?? ""
        text = text + logText + "\n"
        textView.text = text
    }
    
}
