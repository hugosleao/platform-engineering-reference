class ExceptionPessoaJaCadastrada(Exception):
    def __init__(self, cpf):
        self.message = f"Pessoa já cadastrada com o cpf {cpf}"
        super().__init__(self.message)
    
class ExcetionPessoaNaoEstaCadastrada(Exception):
    def __init__(self):
        self.message = "Pessoa não cadastrada !"
        super().__init__(self.message)