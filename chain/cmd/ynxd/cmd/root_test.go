package cmd

import "testing"

func TestNewRootCmdDoesNotPanic(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("NewRootCmd panicked: %v", r)
		}
	}()

	cmd := NewRootCmd()
	if cmd == nil {
		t.Fatal("expected root command")
	}
}
