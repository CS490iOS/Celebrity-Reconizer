//
//  SavedCelebritiesViewController.swift
//  CelebrityRecognition
//
//  Created by Shaurya Sinha on 17/02/18.
//  Copyright © 2018 CS490Team. All rights reserved.
//

import UIKit
import ALCameraViewController
import AWSRekognition
import FirebaseStorage
import FirebaseAuth

class SavedCelebritiesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    let recognition = AWSRekognition.default()
    var faces = [AWSRekognitionCelebrity?]()
    var currentCelebrity = AWSRekognitionCelebrity()
    var takenPictureView = UIImageView()
    var recognizedCelebrity : Celebrity?
    var imageUrl: URL?

    var celebrityName: String?
    let storage = Storage.storage(url: "gs://celebrity-recognition-701af.appspot.com/")
    
    // Variables for AWS Rekognition
    var sourceImage: UIImage?
    
    var posts = [Post]()
    
    @IBAction func onCamera(_ sender: Any) {
        let cameraVC = CameraViewController { (image, asset) in
            if let sourceImage = image{
            self.sourceImage = sourceImage
            let group = DispatchGroup()
            let imageJPG = AWSRekognitionImage()
            imageJPG?.bytes = UIImageJPEGRepresentation(self.sourceImage!, 0.6)
            
            guard let request = AWSRekognitionRecognizeCelebritiesRequest() else {
                puts("Unable to initialize AWSRekognitionDetectLabelsRequest.")
                return
            }
            request.image = imageJPG
            group.enter()
            self.recognition.recognizeCelebrities(request) { (response, error) in
                if error == nil{
                    let faces = response?.celebrityFaces
                    self.faces = faces!
                    self.currentCelebrity = faces?[0]
                    
                    if let name = faces?[0].name{
                        self.celebrityName = name
                    }else{
                        print("No recognition Found")
                    }
                }else{
                    print("The error is : \n\n\n" + (error.debugDescription))
                }
                group.leave()
            }
            group.wait()
            group.enter()
            MovieApiManager().getCelebrity(searchQuery: self.celebrityName!) { (celeb, error) in
                if let celeb = celeb{
                    self.recognizedCelebrity = celeb
                    print(self.recognizedCelebrity?.name)
                }else{
                    print("\nMovie API didn't work\n")
                }
                
                group.enter()
                MovieApiManager().getImage(id: self.recognizedCelebrity!.id){ (url, error) in
                    if let url = url{
                        print("\nURL returned is \(url.absoluteString)\n")
                        self.imageUrl = url
                    }else{
                        print("URL NOT FOUND")
                    }
                    group.leave()
                }
                group.leave()
            }
            group.notify(queue: .main, execute: {
                //print("\nURL set is \(self.imageUrl?.absoluteString)\n")
               // self.takenPictureView.af_setImage(withURL: self.imageUrl!)
                self.performSegue(withIdentifier: "detailSegue", sender: nil)
            })
            }
            
            self.dismiss(animated: true){
                PostService.create(for: self.sourceImage!, name: self.celebrityName!)
            }
        }
        present(cameraVC, animated: true, completion: nil)
        
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
            return posts.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SavedCelebritiesTableViewCell
        let post = posts[indexPath.row]
        
        let imageURL = URL(string: post.imageURL)
        
        cell.faceImageView.af_setImage(withURL: imageURL!)
        cell.nameLabel.text = post.name
        print("post image url: \(post.imageURL) | \(post.key)")
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let post = posts[indexPath.row]
        
    }
    
   // public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
       // return 200
    //}
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let refreshcontrol = UIRefreshControl()
        refreshcontrol.addTarget(self, action: #selector(refreshControlAction(_:)), for: UIControlEvents.valueChanged)
        tableView.insertSubview(refreshcontrol, at: 0)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 300
        tableView.rowHeight = UITableViewAutomaticDimension
        
        PostService.posts(for: Auth.auth().currentUser!) { (posts) in
            self.posts = posts
            self.tableView.reloadData()
        }
    }
    
    @objc func refreshControlAction(_ refreshControl: UIRefreshControl){
        PostService.posts(for: Auth.auth().currentUser!) { (posts) in
            self.posts = posts
            self.tableView.reloadData()
        }
        refreshControl.endRefreshing()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let dest = segue.destination as! CelebrityInfoViewController
        
        if(segue.identifier == "detailSegue"){
            if let celeb = self.recognizedCelebrity{
                dest.recognizedCelebrity = celeb
            }else{
                print("Celeb not found"    )
            }
            dest.imageUrl = self.imageUrl
            
            var movies: [Movie] = []
            for movie in (self.recognizedCelebrity!.knownFor)!{
                let temp = movie as! [String: Any]
                let movie = Movie(dictionary: temp)
                movies.append(movie)
            }
            dest.Movies = movies
        }
        if(segue.identifier == "tableSegue"){
            
        }
        
    }
    

}
