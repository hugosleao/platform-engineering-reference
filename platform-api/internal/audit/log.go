package audit

import (
	"context"
	"time"

	"go.uber.org/zap"
)

type Entry struct {
	ID        string    `json:"id"`
	Action    string    `json:"action"`
	Actor     string    `json:"actor"`
	Resource  string    `json:"resource"`
	Status    string    `json:"status"`
	Message   string    `json:"message,omitempty"`
	Timestamp time.Time `json:"timestamp"`
}

type Logger struct {
	log     *zap.Logger
	entries []Entry
}

func NewLogger(log *zap.Logger) *Logger {
	return &Logger{log: log}
}

type ctxKey string

const actorKey ctxKey = "actor"

func WithActor(ctx context.Context, actor string) context.Context {
	return context.WithValue(ctx, actorKey, actor)
}

func ActorFrom(ctx context.Context) string {
	if v, ok := ctx.Value(actorKey).(string); ok {
		return v
	}
	return "unknown"
}

func (l *Logger) Record(ctx context.Context, action, resource, status, message string) Entry {
	e := Entry{
		ID:        time.Now().Format("20060102150405.000000000"),
		Action:    action,
		Actor:     ActorFrom(ctx),
		Resource:  resource,
		Status:    status,
		Message:   message,
		Timestamp: time.Now().UTC(),
	}
	l.entries = append(l.entries, e)
	l.log.Info("audit",
		zap.String("action", action),
		zap.String("actor", e.Actor),
		zap.String("resource", resource),
		zap.String("status", status),
		zap.String("message", message),
	)
	return e
}

func (l *Logger) List() []Entry {
	return l.entries
}
