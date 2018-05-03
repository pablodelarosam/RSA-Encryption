//
//  Constants.swift
//  RSA-Encryption
//
//  Created by Pablo de la Rosa Michicol on 5/2/18.
//  Copyright © 2018 CraftCode. All rights reserved.
//

import Foundation
import Firebase

struct Constants
{
    struct refs
    {
        static let databaseRoot = Database.database().reference()
        static let databaseChats = databaseRoot.child("chats")
    }
}
