package transport

import (
	"encoding/json"
	"strconv"
	"time"
)

// ConnState describes the state of a connection.
type ConnState struct {
	// ConnectedFor is the duration for which the connection has been connected.
	ConnectedFor time.Duration `json:"connected_for"`
	// StreamStates describes the state of streams.
	StreamStates map[byte]StreamState `json:"stream_states"`
	// SendRateLimiterDelay is the delay imposed by the send rate limiter.
	//
	// Only applies to TCP.
	SendRateLimiterDelay time.Duration `json:"send_rate_limiter_delay"`
	// RecvRateLimiterDelay is the delay imposed by the receive rate limiter.
	//
	// Only applies to TCP.
	RecvRateLimiterDelay time.Duration `json:"recv_rate_limiter_delay"`
}

// MarshalJSON converts StreamStates keys to strings.
//
// encoding/json does not support non-string map keys, but StreamStates uses
// byte keys (stream IDs). Without this, /net_info errors whenever peers exist.
func (c ConnState) MarshalJSON() ([]byte, error) {
	streamStates := make(map[string]StreamState, len(c.StreamStates))
	for key, value := range c.StreamStates {
		streamStates[strconv.Itoa(int(key))] = value
	}

	type jsonConnState struct {
		ConnectedFor          time.Duration          `json:"connected_for"`
		StreamStates          map[string]StreamState `json:"stream_states"`
		SendRateLimiterDelay  time.Duration          `json:"send_rate_limiter_delay"`
		RecvRateLimiterDelay  time.Duration          `json:"recv_rate_limiter_delay"`
	}

	return json.Marshal(jsonConnState{
		ConnectedFor:         c.ConnectedFor,
		StreamStates:         streamStates,
		SendRateLimiterDelay: c.SendRateLimiterDelay,
		RecvRateLimiterDelay: c.RecvRateLimiterDelay,
	})
}

// StreamState is the state of a stream.
type StreamState struct {
	// SendQueueSize is the size of the send queue.
	SendQueueSize int `json:"send_queue_size"`
	// SendQueueCapacity is the capacity of the send queue.
	SendQueueCapacity int `json:"send_queue_capacity"`
}
