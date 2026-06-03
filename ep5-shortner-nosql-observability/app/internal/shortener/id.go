package shortener

import (
	"math/big"
	"strings"

	"github.com/google/uuid"
)

func NewID() (uuid.UUID, error) {
	return uuid.NewV7()
}

func SlugFromUUID(u uuid.UUID) string {
	var n big.Int
	n.SetBytes(u[10:16]) // 6 bytes = 48 bits of random material
	s := n.Text(62)
	if len(s) >= 8 {
		return s[len(s)-8:]
	}
	return strings.Repeat("0", 8-len(s)) + s
}
