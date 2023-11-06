//
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

protocol ItemService {
    ///API service protocol for the API adaptors
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void)
}



class ListViewController: UITableViewController {
    
    var service: ItemService?
    var items = [ItemViewModel]()
    
    var retryCount = 0
    var maxRetryCount = 0
    var shouldRetry = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if tableView.numberOfRows(inSection: 0) == 0 {
            refresh()
        }
    }
    
    @objc private func refresh() {
        refreshControl?.beginRefreshing()
        service?.loadItems(completion: handleAPIResult)
    }
    
    private func handleAPIResult(_ result: Result<[ItemViewModel], Error>) {
        
        switch result {
        case let .success(items):
            
            self.items = items
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
            
            
        case let .failure(error):
            
            self.show(error: error)
            self.refreshControl?.endRefreshing()
        }
    }
    
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ItemCell")
        
        cell.configure(item)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        item.select()
        //reverse change
    }
    
    
}


extension UITableViewCell {
    
    func configure(_ vm: ItemViewModel) {
        
        textLabel?.text = vm.title
        detailTextLabel?.text = vm.subtitle
        
        
    }
}
