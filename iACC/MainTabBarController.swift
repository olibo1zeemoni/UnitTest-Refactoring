//	
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
    
    var friendsCache: FriendsCache!
    
    convenience init(friendsCache: FriendsCache) {
        self.init(nibName: nil, bundle: nil)
        self.friendsCache = friendsCache
        self.setupViewController()
    }
    
    private func setupViewController() {
        viewControllers = [
            makeNav(for: makeFriendsList(), title: "Friends", icon: "person.2.fill"),
            makeTransfersList(),
            makeNav(for: makeCardsList(), title: "Cards", icon: "creditcard.fill")
        ]
    }
    
    private func makeNav(for vc: UIViewController, title: String, icon: String) -> UIViewController {
        vc.navigationItem.largeTitleDisplayMode = .always
        
        let nav = UINavigationController(rootViewController: vc)
        nav.tabBarItem.image = UIImage(
            systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(scale: .large)
        )
        nav.tabBarItem.title = title
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }
    
    private func makeTransfersList() -> UIViewController {
        let sent = makeSentTransfersList()
        sent.navigationItem.title = "Sent"
        sent.navigationItem.largeTitleDisplayMode = .always
        
        let received = makeReceivedTransfersList()
        received.navigationItem.title = "Received"
        received.navigationItem.largeTitleDisplayMode = .always
        
        let vc = SegmentNavigationViewController(first: sent, second: received)
        vc.tabBarItem.image = UIImage(
            systemName: "arrow.left.arrow.right",
            withConfiguration: UIImage.SymbolConfiguration(scale: .large)
        )
        vc.title = "Transfers"
        vc.navigationBar.prefersLargeTitles = true
        return vc
    }
    
    private func makeFriendsList() -> ListViewController {
        let vc = ListViewController()
        vc.title = "Friends"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(addFriend))
        
        let isPremium = User.shared?.isPremium == true
        
        let api = FriendAPIItemServiceAdaptor(api: FriendsAPI.shared,
                                              cache: isPremium ? friendsCache : NullFriendsCache(),
                                              select: { [weak vc] item in
            vc?.select(friend: item)
        }).retry(2)
        
        let cache = FriendsCacheItemServiceAdaptor(cache: friendsCache) { [weak vc] item in
            vc?.select(friend: item)
        }
        //TODO: compare FriendAPIItemService and FriendCacheItemService adaptors
        vc.service = isPremium ? api.fallback(cache) : api
        
        
        return vc
    }
    
    private func makeSentTransfersList() -> ListViewController {
        let vc = ListViewController()
        vc.navigationItem.title = "Sent"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: vc, action: #selector(sendMoney))
        
        vc.service = SentTransfersAPIItemServiceAdaptor(api: TransfersAPI.shared,
                                                    select: { [weak vc] item in
            vc?.select(transfer: item)
        }).retry(1)
        
        return vc
    }
    
    
    
    private func makeReceivedTransfersList() -> ListViewController {
        let vc = ListViewController()
        vc.navigationItem.title = "Received"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: vc, action: #selector(requestMoney))
        
        
        vc.service = ReceivedTransfersAPIItemServiceAdaptor(api: TransfersAPI.shared,
                                                    select: { [weak vc] item in
            vc?.select(transfer: item)
        }).retry(1)
        return vc
    }
    
    private func makeCardsList() -> ListViewController {
        let vc = ListViewController()
        vc.title = "Cards"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(addCard))
        
        vc.service = CardAPIItemServiceAdaptor(api: CardAPI.shared,
                                               select: { [weak vc] card in
            vc?.select(card: card)
        })
        
        return vc
    }
    
}

class NullFriendsCache: FriendsCache {
    override func save(_ newFriends: [Friend]) {
        
    }
    
}

extension ItemService {
    func fallback(_ fallback: ItemService) -> ItemService {
        ItemServiceWithFallback(primary: self, fallback: fallback)
    }
    
    func retry(_ retryCount: UInt) -> ItemService {
        var service: ItemService = self
        for _ in 0..<retryCount {
            service = fallback(self)
        }
        return service
    }
}


struct ItemServiceWithFallback: ItemService {
    let primary: ItemService
    let fallback: ItemService
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        primary.loadItems { result in
            switch result {
            case .success:
                completion(result)
            case .failure:
                fallback.loadItems(completion: completion)
            }
        }
    }
}


//TODO:  - moveAPIServiceAdaptors -

struct FriendAPIItemServiceAdaptor: ItemService {
    let api: FriendsAPI
    let cache: FriendsCache
    let select: (Friend) -> Void
    
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadFriends { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ items in
                    cache.save(items)
                    
                    return items.map { item in
                        ItemViewModel(friend: item) {
                            select(item)
                        }
                    }
                }))
            }
        }
    }
}


struct FriendsCacheItemServiceAdaptor: ItemService {
    let cache: FriendsCache
    let select: (Friend) -> Void
    
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        cache.loadFriends { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ items in
                     items.map { item in
                        ItemViewModel(friend: item) {
                            select(item)
                        }
                    }
                }))
            }
        }
    }
}



struct CardAPIItemServiceAdaptor: ItemService {
    let api: CardAPI
    let select: (Card) -> Void
    
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadCards { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map{ cards in
                    cards.map{ card in
                        ItemViewModel(card: card) {
                            select(card)
                        }
                    }
                })
            }
        }
        
        
        
    }
}

struct ReceivedTransfersAPIItemServiceAdaptor: ItemService {
    let api: TransfersAPI
    let select: (Transfer) -> Void
    
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        
        
        api.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ transfers in
                    transfers.filter{!$0.isSender }
                    .map { transfer in
                        ItemViewModel(transfer: transfer, longDateStyle: false) {
                            select(transfer)
                        }
                    }
                }))
            }
        }
        
    }
    
}
struct SentTransfersAPIItemServiceAdaptor: ItemService {
    let api: TransfersAPI
    let select: (Transfer) -> Void
    
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        
        
        api.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ transfers in
                    transfers.filter{ $0.isSender }
                    .map { transfer in
                        ItemViewModel(transfer: transfer, longDateStyle: true) {
                            select(transfer)
                        }
                    }
                }))
            }
        }
        
    }
    
}
