from marshmallow import Schema, fields

class Pessoa:
    def __init__(self, nome, cpf ):
        self.__nome = nome
        self.__cpf = cpf

    @property
    def nome(self):
        return self.__nome

    @property
    def cpf(self):
        return self.__cpf

class PessoaSchema(Schema):
    nome = fields.Str()
    cpf = fields.Str()