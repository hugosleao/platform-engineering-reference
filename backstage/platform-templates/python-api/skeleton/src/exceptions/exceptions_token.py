class ExeptionToken(Exception):
    def __init__(self, mensagem):
        self.message = f'Token {mensagem}'
        super().__init__(self.message)