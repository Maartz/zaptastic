//
//  GameScene.swift
//  zaptastic
//
//  Created by maartz on 24/10/2021.
//

import SpriteKit
import CoreMotion

enum CollisionTypes: UInt32 {
    case player = 1
    case playerWeapon = 2
    case enemy = 4
    case enemyWeapon = 8
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    let player = SKSpriteNode(imageNamed: "player")
    let motionManager = CMMotionManager()
    
    var isPlayerAlive = true
    var playerShields = 10
    var levelNumber = 0
    var waveNumber = 0
    
    let positions = Array(stride(from: -320, through: 320, by: 80))
    
    let waves = Bundle.main.decode([Wave].self, from: "waves.json")
    let enemyTypes = Bundle.main.decode([EnemyType].self, from: "enemy-types.json")
    
    override func didMove(to view: SKView) {
        if let particles = SKEmitterNode(fileNamed: "Starfield") {
            particles.position = CGPoint(x: 1080, y: 0)
            particles.zPosition = -1
            particles.advanceSimulationTime(60)
            addChild(particles)
        }
        
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        player.name = "player"
        player.position.x = frame.minX + 75
        player.zPosition = 1
        player.physicsBody = SKPhysicsBody(texture: player.texture!, size: player.texture!.size())
        player.physicsBody?.categoryBitMask = CollisionTypes.player.rawValue
        player.physicsBody?.collisionBitMask = CollisionTypes.enemy.rawValue | CollisionTypes.enemyWeapon.rawValue
        player.physicsBody?.contactTestBitMask = CollisionTypes.enemy.rawValue | CollisionTypes.enemyWeapon.rawValue
        player.physicsBody?.isDynamic = false
        addChild(player)
        
        motionManager.startAccelerometerUpdates()
        
        
      
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isPlayerAlive else { return }
        
        let shot = SKSpriteNode(imageNamed: "playerWeapon")
        shot.name = "playerWeapon"
        shot.position = player.position
        shot.physicsBody = SKPhysicsBody(rectangleOf: shot.size)
        shot.physicsBody?.categoryBitMask = CollisionTypes.playerWeapon.rawValue
        shot.physicsBody?.contactTestBitMask = CollisionTypes.enemy.rawValue
        shot.physicsBody?.collisionBitMask = CollisionTypes.enemy.rawValue
        addChild(shot)
        
        let movement = SKAction.move(to: CGPoint(x: 1900, y: shot.position.y), duration: 10)
        let sequence = SKAction.sequence([movement, .removeFromParent()])
        shot.run(sequence)
    }
    
    override func update(_ currentTime: TimeInterval) {
        if let accelerometerData = motionManager.accelerometerData {
            player.position.y += CGFloat(accelerometerData.acceleration.x * 50)

            if player.position.y < frame.minY {
                player.position.y = frame.minY
            } else if player.position.y > frame.maxY {
                player.position.y = frame.maxY
            }
        }

        for child in children {
            if child.frame.maxX < 0 {
                if !frame.intersects(child.frame) {
                    child.removeFromParent()
                }
            }
            
            let activeEnemies = children.compactMap {
                $0 as? EnemyNode
            }
            
            if activeEnemies.isEmpty {
                createWave()
            }
            
            for enemy in activeEnemies {
                guard frame.intersects(enemy.frame) else { continue }
                
                if enemy.lastFireTime + 1 < currentTime {
                    enemy.lastFireTime = currentTime
                    
                    if Int.random(in: 0...6) == 0 {
                        enemy.fire()
                    }
                }
            }
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node else { return }
        guard let nodeB = contact.bodyB.node else { return }
        
        let sortedNodes = [nodeA, nodeB].sorted { $0.name ?? "" < $1.name ?? "" }
        let firstNode = sortedNodes[0]
        let secondNode = sortedNodes[1]
        
        if secondNode.name == "player" {
            guard isPlayerAlive else { return }
            
            if let explosion = SKEmitterNode(fileNamed: "Explosion") {
                explosion.position = firstNode.position
                addChild(explosion)
            }
            
           playerShields -= 1
            
            if playerShields == 0 {
                gameOver()
                secondNode.removeFromParent()
            }
            
            firstNode.removeFromParent()
        } else if let enemy = firstNode as? EnemyNode {
            enemy.shields -= 1
            
            if enemy.shields == 0 {
                if let explosion = SKEmitterNode(fileNamed: "Explosion") {
                    explosion.position = enemy.position
                    addChild(explosion)
                }
                
                firstNode.removeFromParent()
            }
            
            if let explosion = SKEmitterNode(fileNamed: "Explosion") {
                explosion.position = secondNode.position
                addChild(explosion)
            }
            
            secondNode.removeFromParent()
        } else {
            if let explosion = SKEmitterNode(fileNamed: "Explosion") {
                explosion.position = secondNode.position
                addChild(explosion)
            }
            
            firstNode.removeFromParent()
            secondNode.removeFromParent()
        }
    }
    
    func createWave() {
        guard isPlayerAlive else {return}
        
        if waveNumber == waves.count {
            levelNumber += 1
            waveNumber = 0
        }
        
        let currentWave = waves[waveNumber]
        waveNumber += 1
        
        let enemyOffsetX: CGFloat = 100
        let enemyStartX = 600
        
        let maximumEnemyType = min(enemyTypes.count, levelNumber + 1)
        let enemyType = Int.random(in: 0..<maximumEnemyType)
        
        if currentWave.enemies.isEmpty {
            // if this is a random level create enemies at all positions
            for (index, position) in positions.shuffled().enumerated() {
                addChild(EnemyNode(type: enemyTypes[enemyType], startPosition: CGPoint(x: enemyStartX, y: position), xOffset: enemyOffsetX * CGFloat(index * 3), moveStraight: true))
            }
        } else {
            // otherwise create enemies only where requested in the JSON
            for enemy in currentWave.enemies {
                let node = EnemyNode(type: enemyTypes[enemyType], startPosition: CGPoint(x: enemyStartX, y: positions[enemy.position]), xOffset: enemyOffsetX * enemy.xOffset, moveStraight: enemy.moveStraight)
                addChild(node)
            }
        }
    }
    
    func gameOver() {
        isPlayerAlive = false
        
        if let explosion = SKEmitterNode(fileNamed: "Explosion") {
            explosion.position = player.position
            addChild(explosion)
        }
        
        let gameOver = SKSpriteNode(imageNamed: "gameOver")
        addChild(gameOver)
    }
}
