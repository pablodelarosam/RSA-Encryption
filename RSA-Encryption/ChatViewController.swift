//
//  ChatViewController.swift
//  RSA-Encryption
//
//  Created by Pablo de la Rosa Michicol on 5/2/18.
//  Copyright © 2018 CraftCode. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import Heimdall

class ChatViewController: JSQMessagesViewController {
    
    var messages = [JSQMessage]()
    var pubKeyDict = [String: Data]() // Saves all the public key for a given userId
    
    lazy var outgoingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }()

    lazy var incomingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
      
        let defaults = UserDefaults.standard
        
        if  let id = defaults.string(forKey: "jsq_id"),
            let name = defaults.string(forKey: "jsq_name")
        {
            senderId = id
            senderDisplayName = name
        }
        else
        {
            senderId = String(arc4random_uniform(999999))
            senderDisplayName = ""
            
            defaults.set(senderId, forKey: "jsq_id")
            defaults.synchronize()
            
            showDisplayNameDialog()
        }
        
        title = "Chat: \(senderDisplayName!)"
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showDisplayNameDialog))
        tapGesture.numberOfTapsRequired = 1
        
        navigationController?.navigationBar.addGestureRecognizer(tapGesture)
        
        inputToolbar.contentView.leftBarButtonItem = nil
        collectionView.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        let query = Constants.refs.databaseChats.queryLimited(toLast: 10)
        
        _ = query.observe(.childAdded, with: { [weak self] snapshot in
            
            if  let data        = snapshot.value as? [String: String],
                let id          = data["sender_id"],
                let name        = data["name"],
                let text        = data["text"],
                !text.isEmpty
            {
                if let message = JSQMessage(senderId: id, displayName: name, text: text)
                {
                    
                    self?.decryptRSA(message: text)
                    print(message.text)
                    self?.messages.append(message)
                    
                    self?.finishReceivingMessage()
                }
            }
        })
        
    }
    
    
    @objc func showDisplayNameDialog()
    {
        let defaults = UserDefaults.standard
        
        let alert = UIAlertController(title: "Your Display Name", message: "Before you can chat, please choose a display name. Others will see this name when you send chat messages. You can change your display name again by tapping the navigation bar.", preferredStyle: .alert)
        
        alert.addTextField { textField in
            
            if let name = defaults.string(forKey: "jsq_name")
            {
                textField.text = name
            }
            else
            {
                let names = ["Pablo de la Rosa", "Alina de la Rosa", "Rana Raúl", "Trillian", "Slartibartfast", "Humma Kavula", "Deep Thought"]
                textField.text = names[Int(arc4random_uniform(UInt32(names.count)))]
            }
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self, weak alert] _ in
            
            if let textField = alert?.textFields?[0], !textField.text!.isEmpty {
                
                self?.senderDisplayName = textField.text
                
                self?.title = "Chat: \(self!.senderDisplayName!)"
                
                defaults.set(textField.text, forKey: "jsq_name")
                defaults.synchronize()
            }
        }))
        
        present(alert, animated: true, completion: nil)
    }

    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData!
    {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource!
    {
        return messages[indexPath.item].senderId == senderId ? outgoingBubble : incomingBubble
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource!
    {
        return nil
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString!
    {
        return messages[indexPath.item].senderId == senderId ? nil : NSAttributedString(string: messages[indexPath.item].senderDisplayName)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat
    {
        return messages[indexPath.item].senderId == senderId ? 0 : 15
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!, receiverID: String!)
    {
        let ref = Constants.refs.databaseChats.childByAutoId() //crear nuevo hijo con nuevo id
        let pk: Data
        //RSA(text)
        if !pubKeyDict.keys.contains(receiverId){ // Verify if the public key of the user exists
            pk = createPublicKey(tag: receiverId)
            pubKeyDict[receiverId] = pk
        }
        let ciphertext = encryptRSA(keyData: pk, message: text)
        
        let message = ["sender_id": senderId, "name": senderDisplayName, "text": text, "encrypted_message": ciphertext]  //encrypted = pub key
        
        ref.setValue(message)
        
        finishSendingMessage()
    }
    
    func encryptRSA(keyData: Data, message: String) -> String?{
        // On other party, assuming keyData contains the received public key data
        if let partnerHeimdall = Heimdall(publicTag: "com.example.partner", publicKeyData: keyData) {
            // Transmit some message to the partner
            let encryptedMessage = partnerHeimdall.encrypt(message)
            return encryptedMessage
            // Transmit the encryptedMessage back to the origin of the public key
        }
        return nil
    }
    
    func decryptRSA(message: String){
        let localHeimdall = Heimdall(tagPrefix: "com.example")
        if let heimdall = localHeimdall {
            if let decryptedMessage = heimdall.decrypt(message) {
                print(decryptedMessage) // "This is a secret message to my partner"
            }
        }
    }
    
    func createPublicKey(tag: String) -> Data? {
        let localHeimdall = Heimdall(tagPrefix: "com.example")
        if let heimdall = localHeimdall, let publicKeyData = heimdall.publicKeyDataX509() {
            
            var publicKeyString = publicKeyData.base64EncodedString()
            publicKeyString = publicKeyString.replacingOccurrences(of: "/", with: "_")
            publicKeyString = publicKeyString.replacingOccurrences(of: "+", with: "-")
            print("Public Key String: \(publicKeyString)") // Something along the lines of "MIGfMA0GCSqGSIb3DQEBAQUAA..."
            
            // Data transmission of public key to the other party
            return publicKeyData
        }
        return nil
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
