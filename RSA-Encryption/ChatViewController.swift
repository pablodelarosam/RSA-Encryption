//
//  ChatViewController.swift
//  RSA-Encryption
//
//  Created by Pablo de la Rosa Michicol on 5/2/18.
//  Copyright © 2018 CraftCode. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import Firebase
import Heimdall


class ChatViewController: JSQMessagesViewController {
    
    var messages = [JSQMessage]()
    var pubKeyDict = [String: Data]() // Saves all the public key for a given userId
    
    private lazy var messageRef: DatabaseReference = self.channelRef!.child("messages")
    private var newMessageRefHandle: DatabaseHandle?
    
    lazy var outgoingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }()

    lazy var incomingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }()
    
    var channelRef: DatabaseReference?
    var channel: Channel? {
        didSet {
            title = channel?.name
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
      
        
        self.senderId = Auth.auth().currentUser?.uid
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        observeMessages() // Manipulate the messages to decipher them
    }
    
    private func observeMessages() {
        messageRef = channelRef!.child("messages")
        let messageQuery = messageRef.queryLimited(toLast:25)
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            let messageData = snapshot.value as! Dictionary<String, String>
            if let id = messageData["senderId"] as String!, let name = messageData["senderName"] as String!, var text = messageData["text"] as String!, var decript = messageData["decryptenMessage"], text.characters.count > 0 {
              
                 // Decrypt text with identifier
                self.addMessage(withId: id, name: name, text: decript)
                self.finishReceivingMessage()
            } else {
            //    print("Error! Could not decode message data")
            }
        })
    }
    
    func createPublicKey(tag: String) -> Data? {
        let localHeimdall = Heimdall(tagPrefix: "com.example")
        if let heimdall = localHeimdall, let publicKeyData = heimdall.publicKeyDataX509() {
            var publicKeyString = publicKeyData.base64EncodedString()
            publicKeyString = publicKeyString.replacingOccurrences(of: "/", with: "_")
            publicKeyString = publicKeyString.replacingOccurrences(of: "+", with: "-")
            print("Public Key String: \(publicKeyString)")
            return publicKeyData // Data transmission of public key to the other party
        }
        return nil
    }
    
    func decryptRSA(tag: String, message: String) -> String?{
        let localHeimdall = Heimdall(tagPrefix: "com.example")
        if let heimdall = localHeimdall {
            if let decryptedMessage = heimdall.decrypt(message) {
                print("Decrypted Message: \(decryptedMessage)")
                return decryptedMessage
            }
            else{
                return ""
            }
        }else{
            return ""
        }
    }
    
    func tryDecryptRSA(tag: String, message: String) -> Bool?{
        let localHeimdall = Heimdall(tagPrefix: "com.example")
        if let heimdall = localHeimdall {
            if let decryptedMessage = heimdall.decrypt(message) {
                return true
            }
            else{
                return false
            }
        }else{
            return false
        }
    }
    
    private func addMessage(withId id: String, name: String, text: String) {
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            messages.append(message)
        }
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
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!)
    {
        let itemRef = messageRef.childByAutoId() // 1
        
        let pk: Data
        var encryptedMessage: String = ""
        var decryptMessage: String = ""
        
        //RSA(text)
        if !pubKeyDict.keys.contains(senderId){ // Verify if the public key of the user exists
            pk = createPublicKey(tag: senderId)!
            pubKeyDict[senderId] = pk
        }else{
            pk = pubKeyDict[senderId]!
        }
        
        if let partnerHeimdall = Heimdall(publicTag: "com.example.partner", publicKeyData: pk) {
            // Transmit some message to the partner
            let message = text!
            var decryptMessage = text!
            
            
            encryptedMessage = partnerHeimdall.encrypt(message)!
            if self.tryDecryptRSA(tag: "com.example", message: encryptedMessage)! {
                decryptMessage = self.decryptRSA(tag: "com.example", message: encryptedMessage)!
            }
         
            print("Encrypted: \(encryptedMessage)")
             print("Decrypted: \(decryptMessage)")
            // Transmit the encryptedMessage back to the origin of the public key
        }
        
        let messageItem = [
            "senderId": senderId!,
            "senderName": senderDisplayName!,
            "text": encryptedMessage,
            "decryptenMessage": text
            ]
        
        itemRef.setValue(messageItem)
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        finishSendingMessage()
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
