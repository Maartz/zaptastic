//
//  EnemyType.swift
//  EnemyType
//
//  Created by maartz on 24/10/2021.
//

import SpriteKit

struct EnemyType: Codable {
    let name: String
    let shields: Int
    let speed: CGFloat
    let powerUpChance: Int
}
