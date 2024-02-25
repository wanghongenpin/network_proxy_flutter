//
//  PictureInPictureView.swift
//  Runner
//
//  Created by wanghongen on 2024/1/9.
//

import SwiftUI

@available(iOS 13.0, *)
class DataSource: ObservableObject {
    @Published var list: [String] = []
    
    func clear() {
        list.removeAll()
    }
}

@available(iOS 13.0, *)
struct PictureInPictureView: View {
    @ObservedObject var dataSource = DataSource()
    
    var body: some View {
       
        ScrollView {
        
            VStack(alignment: .leading, spacing: 1.3){
                
                ForEach((0..<dataSource.list.count).reversed(), id: \.self) {
                    Text(dataSource.list[$0])
                        .font(.system(size: 10))
                        .lineLimit(2)
                        
                    
                    Divider()
                        .frame(maxHeight: 1.3)
                }
                
               
            }
            .padding(5)
            
           
        }
        
    }
    
        func addData(text: String) {
            dataSource.list.append(text);
        }
}
//
//
//class PictureInPictureView: UIView {
//
//    private lazy var viewLabel: UITextView = {
//        let label = UITextView()
//
//        label.textContainer.lineBreakMode = .byCharWrapping
//
//        label.font = UIFont.systemFont(ofSize: 10)
////        label.text = ""
//        label.isEditable = false;
//        label.isSelectable = false;
////        label.font?.setLine
////        label.lineSpacing = 1.2
////        label.textContainer.line
//
//
//        return label
//      }()
//
//    override init(frame: CGRect) {
//       super.init(frame: frame)
//       setupUI()
//   }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//
//    private func setupUI() {
////        backgroundColor = .white
//        addSubview(viewLabel)
//        viewLabel.snp.makeConstraints { (make) -> Void in
//            make.edges.equalToSuperview()
//        }
//    }
//
//    func addData(text: String) {
//        let str = "• " + text + "\n" + (viewLabel.text ?? "");
//        self.viewLabel.text = str;
//    }
//}
