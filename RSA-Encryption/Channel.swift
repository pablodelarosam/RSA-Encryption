//
//  Channel.swift
//  RSA-Encryption
//
//  Created by Pablo de la Rosa Michicol on 5/3/18.
//  Copyright © 2018 CraftCode. All rights reserved.
//

import Foundation

internal class Channel {
    internal let id: String
    internal let name: String
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
