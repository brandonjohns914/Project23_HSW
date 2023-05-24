//
//  GameScene.swift
//  Project23
//
//  Created by Brandon Johns on 5/19/23.
//

import SpriteKit
import GameplayKit
import AVFoundation

class GameScene: SKScene
{
    
    let never: Int = 1
    let always: Int  = 0

    enum ForceBomb
    {
        case never, always, random
    }
    
    enum SequenceType: CaseIterable                                                  //makes it so it can be moved one by one
    {
        case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
    }
    
    var gameScore: SKLabelNode!
    var activeSliceBG: SKShapeNode!                                                 //slice background
    var activeSliceFG: SKShapeNode!                                                 //slice forground
    var bombSoundEffect: AVAudioPlayer?
    
    var sequence = [SequenceType]()                                                 //which enemies are created
    var livesImages = [SKSpriteNode]()
    var activeSlicePoints = [CGPoint]()
    var activeEnemies = [SKSpriteNode]()
    
    var isGameEnded = false
    var nextSequenceQueued = true                                                   // all enemies are destoried and ready to create more
    var popupTime = 0.9                                                             // amount of time between enemny creation
    var sequencePosition = 0                                                        //where we are according to sequence array
    var chainDelay = 3.0                                                            // how long to wait if the sequence type is chain/fastchain
    var lives = 3
    
    var score = 0
    {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }//score
    
    var isSwooshSoundActive = false
    
    
    
    override func didMove(to view: SKView)
    {
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)                                  //gravity not as strong as default
        physicsWorld.speed = 0.85                                                       //speed of game a little slower
        
        createScore()
        createLives()
        createSlices()
        
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]             //starting sequence
        
        for _ in 0 ... 1000                                                             // play until someone dies
        {
            if let nextSequence = SequenceType.allCases.randomElement()                 //random sequence
            {                                                                           //all cases comes from CaseIterable so this pulls out random element
                sequence.append(nextSequence)
            }//nextSequence
        }//for
        // call toss enemies after 2 seconds have passed
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.tossEnemies()
        }//async
        
    }//didMove
    
    func createScore()                                                                 //score label in bottom left corner
    {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        addChild(gameScore)
        
        gameScore.position = CGPoint(x: 8, y: 8)
        score = 0
    }//createScore
    
    func createLives()                                                              //creates 3 lives in the top Right corner
    {                                                                               //cross off lives when player looses one
        for i in 0 ..< 3
        {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            
            livesImages.append(spriteNode)
        }//for
        
    }//createLives
    
    
    func createSlices()
    {
        activeSliceBG = SKShapeNode()                                               //SKShapeNode allows lines to be drawn to the screen
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 3                                                 //on top of BG
        
        activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)  //yellow color
        activeSliceBG.lineWidth = 9
        
        activeSliceFG.strokeColor = UIColor.white
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }//createSlices
    
    
    
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        
        guard isGameEnded == false else {return }
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)                                 //touch on screen
        
        activeSlicePoints.append(location)                                      //array of all points the user touches
        redrawActiveSlice()
        
        if !isSwooshSoundActive
        {
            playSwooshSound()
        }
        
        
        let nodesAtPoint = nodes(at: location)                                  // all nodes at location
        
        for case let node as SKSpriteNode in nodesAtPoint                  // only enters loop if its an SKSpriteNode
        {
            if node.name == "enemy"
            {                                                                   //destory pengiun
                if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy")
                {
                    emitter.position = node.position
                    addChild(emitter)
                }//sliceHitEnemy
                
                node.name = ""
                node.physicsBody?.isDynamic = false
                
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                
                let group = SKAction.group([scaleOut, fadeOut])                         // run at the same time
                
                let seq = SKAction.sequence([group, .removeFromParent()])               // fade/scale out then remove it from parent and destory the noide
                
                node.run(seq)
                
                score += 1
                
                if let index = activeEnemies.firstIndex(of: node)
                {
                    activeEnemies.remove(at: index)
                }//index
                
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))     // sound once penguin is hit
                
            }// enemy
            else if node.name == "bomb"
            {
                guard let bombContainer = node.parent as? SKSpriteNode else
                {
                    continue
                }
                if let emitter = SKEmitterNode(fileNamed: "sliceHitBomb") {
                    emitter.position = bombContainer.position
                    addChild(emitter)
                }
                
                node.name = ""                                                              //clear out node cant hit again
                bombContainer.physicsBody?.isDynamic = false
                
                let scaleOut = SKAction.scale(to: 0.001, duration:0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut])                             //scale fade out all the same time
                
                let seq = SKAction.sequence([group, .removeFromParent()])
                bombContainer.run(seq)
                
                if let index = activeEnemies.firstIndex(of: bombContainer)
                {
                    activeEnemies.remove(at: index)                                         //remove from array
                }//index
                
                run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
                endGame(triggeredByBomb: true)
            }//bomb
            
            
        }//for
        
        
        
    }//touchesMoved
    
    
    func endGame(triggeredByBomb: Bool)
    {
        if isGameEnded {
            return
        }//isGameEnded
        
        isGameEnded = true
        physicsWorld.speed = 0
        isUserInteractionEnabled = false                                        //user cannot interact
        
        bombSoundEffect?.stop()                                                 //ends bomb sound
        bombSoundEffect = nil
        
        if triggeredByBomb                                                      // all lives gone
        {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }// life gone
        
        let gameOver = SKSpriteNode(imageNamed: "gameOver")
        gameOver.position = CGPoint(x: 512, y: 384)
        gameOver.zPosition = 1
        addChild(gameOver)
    }//endGame
    
    
    
    func playSwooshSound()
    {
        isSwooshSoundActive = true
        let randomNumber = Int.random(in: 1...3)                                //choosing the swoosh 1 2 3
        
        let soundName = "swoosh\(randomNumber).caf"                             //naming swoosh
        
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true) // rund the sound
        
        //completion closre
        run(swooshSound) { [weak self ] in
            self?.isSwooshSoundActive = false
            
        }//run
        
        
        
    }//playSwooshSound
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))                 // touches wait 0.25 to leave the screen
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }//touchesEnded
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }                         //find the touch
        
        // new touch removes all old touches in the array
        activeSlicePoints.removeAll(keepingCapacity: true)
        
        // adding touch points to the array
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        
        
        redrawActiveSlice()                                                     //update SKShapeNode
        
        
        activeSliceBG.removeAllActions()                                        //removes fade out before you start drawing again
        activeSliceFG.removeAllActions()
        
        activeSliceBG.alpha = 1
        activeSliceFG.alpha = 1
    }//touchesBegan
    
    func redrawActiveSlice()
    {
        
        if activeSlicePoints.count < 2                                      // two points is not enough to make aline so exit
        {
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }//activeSlice
        
        // only 12 slice points
        if activeSlicePoints.count > 12                                     //stops the line from getting to long
        {
            activeSlicePoints.removeFirst(activeSlicePoints.count - 12)
        }
        
        //the path being drawn
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])                                 //starting at the first point start drawing hte path
        
        for i in 1 ..< activeSlicePoints.count
        {
            path.addLine(to: activeSlicePoints[i])                          //move the path to this point
        }//for
        
        
        activeSliceBG.path = path.cgPath                                    // assigning the path to FG/BG line
        activeSliceFG.path = path.cgPath
    }//redrawActiveSlice
    
    
    func createEnemy(forceBomb: ForceBomb = .random)
    {
        let enemy: SKSpriteNode
        
        var enemyType = Int.random(in: 0...6)
        
        if forceBomb == .never {
            enemyType = never                                                  // never a bomb
        }//.never
        
        else if forceBomb == .always
        {
            enemyType = always                                                  //aways a bomb
        } //.always
        
        
        if enemyType == always
        {
            enemy = SKSpriteNode()
            enemy.zPosition = 1                                                 //appears ahead
            enemy.name = "bombContainer"
            
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage)                                       //add to container
            
            if bombSoundEffect != nil
            {
                bombSoundEffect?.stop()
                bombSoundEffect = nil                                       // stops bomb soundeffect every time
            }//if
            if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf")       // find sound file
            {
                if let sound = try? AVAudioPlayer(contentsOf: path)
                {
                    bombSoundEffect = sound
                    sound.play()
                }//sound
            }// path
            
            if let emitter = SKEmitterNode(fileNamed: "sliceFuse")
            {
                emitter.position = CGPoint(x: 76, y: 64)
                enemy.addChild(emitter)
            }
            
        }//if
        
        else
        {
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"
        }//else
        
        //position code
        
        let randomPosition = CGPoint(x: Int.random(in: 64...960), y: -128)                                                      //y always off the screen
        enemy.position = randomPosition                                                                                         //where enemy starts
        
        
        let randomAngularVelocity = CGFloat.random(in: -3...3)
        let randomXVelocity: Int
        
        if randomPosition.x < 256
        {
            randomXVelocity = Int.random(in: 8...15)                                                                                  //moves to right faster
        }// if
        
        
        
        else if randomPosition.x < 512
        {
            randomXVelocity = Int.random(in: 3...5)                                                                                   //moves to right slowly
        }//else if
        
        
        else if randomPosition.x < 768
        {
            randomXVelocity = -Int.random(in: 3...5)                                                                                // mvoe to left
        } // else if
        
        else
        {
            randomXVelocity = -Int.random(in: 8...15)                                                                               // move to left quickly
        }//lese
        
        let randomYVelocity = Int.random(in: 24...32)
        
        
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody?.angularVelocity = randomAngularVelocity
        
        enemy.physicsBody?.collisionBitMask =  0                                                                                        // dont bounce off anything
        
        addChild(enemy)
        activeEnemies.append(enemy)
        
        
        
    }//createEnemy
    
    func subtractLife()
    {// penguin falls off screen without being sliced
        
        lives -= 1
        
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life: SKSpriteNode
        
        if lives == 2                                                                       // 2 lives left
        {
            life = livesImages[0]
        }
        else if lives == 1                                                                  // 1 live left
        {
            life = livesImages[1]
        }
        else
        {
            life = livesImages[2]
            endGame(triggeredByBomb: false)
        }
        
        life.texture = SKTexture(imageNamed: "sliceLifeGone")                               //puts in red x
        
        life.xScale = 1.3
        life.yScale = 1.3
        life.run(SKAction.scale(to: 1, duration:0.1))                                       //gets big than shrinks
    }
    
    override func update(_ currentTime: TimeInterval)
    {
        
        if activeEnemies.count > 0              //loop through in reverse and pull out items
        {
            for (index, node) in activeEnemies.enumerated().reversed()
            {
                if node.position.y < -140                                   //falls below -140 remove from  parent
                {
                    node.removeAllActions()
                    
                    if node.name == "enemy"
                    {
                        node.name = ""                                      //clears pengiuns node
                        subtractLife()
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    }// enemy
                    else if node.name == "bombContainer"
                    {
                        node.name = ""                                  //clears bomb node
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                        
                    }//bomb container
                    
                }//if
                
            }//for
        }// activeEnemies.count
        
        else                                                                                    //no current active enemies and next sequence is not queued
        {
            if !nextSequenceQueued
            {
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) {
                    [weak self ] in
                    self?.tossEnemies()
                }
                nextSequenceQueued = true                                                       // stops calling toss enemies again anda gain
            }//if
        }//else
        
        var bombCount = 0
        
        for node in activeEnemies
        {
            if node.name == "bombContainer"
            {
                bombCount += 1
                break
            }// if
        }//for
        
        if bombCount == 0
        {                                                   // no bombs stop fuse
            bombSoundEffect?.stop()
            bombSoundEffect = nil                           // stop bomb sound and destory it
        }//if
        
    }//update
    
    
    func tossEnemies()
    {
        
        guard isGameEnded == false else {return }           //st
        
        popupTime *= 0.991                                  // pop up faster
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02                          // fall speed faster
        
        
        
        let sequenceType = sequence[sequencePosition]
        
        switch sequenceType
        {
        case .oneNoBomb:                                // might/not be a bomb
            createEnemy(forceBomb: .never)
            
        case .one:
            createEnemy()
            
        case .twoWithOneBomb:                          // one bomb/ one not bomb
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
            
        case .two:
            createEnemy()
            createEnemy()
            
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .chain:                                //create enemies over a period of time
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) { [weak self] in self?.createEnemy() } //create enemy after 1/5 of chaindelay
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) { [weak self] in self?.createEnemy() }
            
        case .fastChain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) { [weak self] in self?.createEnemy() }
        }//switch
        
        sequencePosition += 1                                                                                           // go to next sequence item
        nextSequenceQueued = false                                                                                      // there arent any enemies but some are coming
    }//tossEnemies
    
    
}//gameScene
