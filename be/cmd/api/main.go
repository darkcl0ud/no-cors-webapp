package main

import (
	"github.com/darkcl0ud/no-cors-webapp/be/internal/api"
	"github.com/darkcl0ud/no-cors-webapp/be/internal/handler"
	"github.com/gin-gonic/gin"
)

func main() {
	myHandler := handler.Server{}

	r := gin.Default()

	api.RegisterHandlers(r, myHandler)

	err := r.Run(":80")

	if err != nil {
		panic(err)
	}
}
