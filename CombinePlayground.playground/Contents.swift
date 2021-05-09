import UIKit
import Combine

extension Publishers {
 
  private final class MyMapSubscription<Output, Failure: Error>: Subscription {
    
    var subscriber: AnySubscriber<Output,Failure>? = nil
    var value: Output?
    var completion: Subscribers.Completion<Failure>? = nil
    
    init<S>(subscriber: S,
            completion: Subscribers.Completion<Failure>?) where S: Subscriber, Failure == S.Failure, Output == S.Input {
      self.subscriber = AnySubscriber(subscriber)
      self.completion = completion
    }
    
    func request(_ demand: Subscribers.Demand)  {
      if demand != .none {
        return
      }
      
      emit()
    }
    
    // Publisherから値を受け取る
    func receive(_ input: Output) {
      guard subscriber != nil else { return }
      value = input
      emit()
    }
    
    // Publisherからcompletionを受け取る
    func receive(completion: Subscribers.Completion<Failure>) {
      guard let subscriber = subscriber else { return }
      self.subscriber = nil
      self.value = nil
      subscriber.receive(completion: completion)
    }

    func cancel() {
      complete(with: .finished)
    }
    
    private func complete(with completion: Subscribers.Completion<Failure>) {
      guard let subscriber = subscriber else { return }
      self.subscriber = nil
      self.completion = nil
      self.value = nil
      
      subscriber.receive(completion: completion)
    }

    private func emit() {
      guard let subscriber = subscriber, let value = value else { return }
      subscriber.receive(value)
      self.value = nil
      
      if let completion = completion {
        complete(with: completion)
      }
    }
  }
  
  public class MyMap<Upstream, Output> : Publisher where Upstream: Publisher {
    public typealias Failure = Upstream.Failure
    
    public let transform: (Upstream.Output) -> Output
    private let upstream: Upstream
    private var subscription: MyMapSubscription<Output, Failure>?
    private var completion: Subscribers.Completion<Failure>? = nil

    private var subscriber: AnySubscriber<Output,Failure>? = nil

    public init(upstream: Upstream, transform: @escaping (Upstream.Output) -> Output) {
      self.upstream = upstream
      self.transform = transform
    }
    
    public func receive<S>(subscriber: S) where Output == S.Input, S : Subscriber, Upstream.Failure == S.Failure {
      self.subscriber = AnySubscriber(subscriber)
      
//      let subscription = MyMapSubscription(subscriber: subscriber, completion: completion)
//      self.subscription = subscription
//      subscriber.receive(subscription: subscription)

      let sink = AnySubscriber(receiveSubscription: { subscription in
        subscription.request(.unlimited)
      },
      receiveValue: { [weak self] (value: Upstream.Output) -> Subscribers.Demand in
        self?.relay(value)
        return .none
      },
      receiveCompletion: { [weak self] in
        self?.complete($0)
      })

      upstream.subscribe(sink)
    }
    
    private func relay(_ value: Upstream.Output) {
//      guard completion == nil, let subscription = subscription else { return }
//      subscription.receive(transform(value))
      
      guard completion == nil else { return }
      subscriber!.receive(transform(value))
    }
    
    private func complete(_ completion: Subscribers.Completion<Failure>) {
      self.completion = completion
//      guard let subscription = subscription else { return }
//      subscription.receive(completion: completion)
      
      self.subscriber!.receive(completion: completion)
      self.subscriber = nil
    }
  }
}

extension Publisher {
  
  func myMap<T>(_ transform: @escaping (Self.Output) -> T) -> Publishers.MyMap<Self, T> {
    return Publishers.MyMap(upstream: self, transform: transform)
  }
}

[1,2,3,4,5].publisher
  .print("Sample")
  .myMap { value in
    value * 11
  }
  .sink(receiveCompletion: { completion in
    print("completion: \(completion)")
  }, receiveValue: { value in
    print("value: \(value)")
  })
