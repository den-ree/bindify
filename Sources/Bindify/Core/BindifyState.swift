//
//  BindifyState.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

public protocol BindifyState: Equatable & Sendable {}

public protocol BindifyGlobalState: BindifyState {}

public protocol BindifyLocalState: BindifyState {
  init()
}

public struct BindifyStateChange<State: BindifyState>: Equatable, Sendable {
  public enum Trigger: Equatable, Sendable {
    case storeConnection
    case storeUpdate
    case localUpdate
  }

  public let trigger: Trigger
  public let oldState: State
  public let newState: State

  public var isInitial: Bool { trigger == .storeConnection }

  var hasChanged: Bool { oldState != newState }
}
